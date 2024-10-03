#![forbid(unsafe_code)]
#![doc=include_str!("../README.md")]
#![warn(missing_docs)]
#![warn(clippy::missing_docs_in_private_items)]
/// Metadata about the crate, courtesy of built
mod built_info;
/// An Open Policy Agent bundle containing permissionables
mod bundle;
/// Permissionable relations from the ISPyB database
mod permissionables;
/// A [`tower::Service`] which enforces a bearer token requirement
mod require_bearer;

use crate::bundle::{Bundle, NoMetadata};
use axum::{
    body::Bytes,
    extract::State,
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::get,
    Router,
};
use axum_extra::TypedHeader;
use clap::Parser;
use clio::ClioPath;
use glob::Pattern;
use headers::{ETag, HeaderMapExt, IfNoneMatch};
use opentelemetry_otlp::WithExportConfig;
use require_bearer::RequireBearerLayer;
use serde::Serialize;
use sqlx::{mysql::MySqlPoolOptions, MySqlPool};
use std::{
    fmt::Debug,
    fs::File,
    hash::Hash,
    io::Write,
    net::{Ipv4Addr, SocketAddr, SocketAddrV4},
    ops::Add,
    str::FromStr,
    sync::Arc,
    time::Duration,
};
use tokio::{
    net::TcpListener,
    sync::RwLock,
    time::{sleep_until, Instant},
};
use tower_http::trace::{
    DefaultMakeSpan, DefaultOnFailure, DefaultOnRequest, DefaultOnResponse, TraceLayer,
};
use tracing::instrument;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use url::Url;

/// A wrapper containing a [`Bundle`] and the serialzied gzipped archive
struct BundleFile<Metadata>
where
    Metadata: Serialize,
{
    /// The bundle on which the archive is based
    bundle: Bundle<Metadata>,
    /// The serialized bundle as a gzipped tar archive
    file: Bytes,
}

impl<Metadata> TryFrom<Bundle<Metadata>> for BundleFile<Metadata>
where
    Metadata: Debug + Hash + Serialize,
{
    type Error = anyhow::Error;

    fn try_from(bundle: Bundle<Metadata>) -> Result<Self, Self::Error> {
        Ok(Self {
            file: bundle.to_tar_gz()?.into(),
            bundle,
        })
    }
}

/// A thread safe, mutable, wrapper around the [`BundleFile`]
type CurrentBundle = Arc<RwLock<BundleFile<NoMetadata>>>;

/// Bundler acts as an Open Policy Agent bundle server, providing permissionable data from the
/// ISPyB database and static data from local files
#[derive(Debug, Parser)]
#[command(author, version, about, long_about= None)]
#[allow(clippy::large_enum_variant)]
enum Cli {
    /// Run the service providing bundle data
    Serve(ServeArgs),
    /// Output the bundle schema
    BundleSchema(BundleSchemaArgs),
}

/// Arguments to run the service with
#[derive(Debug, Parser)]
struct ServeArgs {
    /// The port to which this application should bind
    #[arg(short, long, env = "BUNDLER_PORT", default_value_t = 80)]
    port: u16,
    /// If enabled, refuse any bundle requests which do not contain this bearer token
    #[arg(long, env = "BUNDLER_REQUIRE_TOKEN")]
    require_token: Option<String>,
    /// The URL of the ISPyB instance which should be connected to
    #[arg(long, env = "BUNDLER_DATABASE_URL")]
    database_url: Url,
    /// The [`tracing::Level`] to log at
    #[arg(long, env = "BUNDLER_LOG_LEVEL", default_value_t = tracing::Level::INFO)]
    log_level: tracing::Level,
    /// The interval at which ISPyB should be polled
    #[arg(long, env = "BUNDLER_POLLING_INTERVAL", default_value_t=humantime::Duration::from(Duration::from_secs(60)))]
    polling_interval: humantime::Duration,
    /// The URL of the OpenTelemetry collector to send traces to
    #[arg(long, env = "BUNDLER_OTEL_COLLECTOR_URL")]
    otel_collector_url: Option<Url>,
    /// Paths to any static data files that should be included in the bundle - can be globs
    #[arg(long, env = "BUNDLER_STATIC_DATA")]
    static_data: Vec<Pattern>,
}

/// Arguments to output the schema with
#[derive(Debug, Parser)]
struct BundleSchemaArgs {
    /// The path to write the schema to
    #[arg(short, long, value_parser = clap::value_parser!(ClioPath).exists().is_dir())]
    path: Option<ClioPath>,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let args = Cli::parse();

    match args {
        Cli::Serve(args) => serve(args).await,
        Cli::BundleSchema(args) => bundle_schema(args),
    }
}

/// Runs the service, pulling fresh bundles from ISPyB/local files and serving them via the API
async fn serve(args: ServeArgs) {
    setup_telemetry(args.log_level, args.otel_collector_url).unwrap();

    let ispyb_pool = connect_ispyb(args.database_url).await.unwrap();
    let current_bundle = fetch_initial_bundle(&args.static_data, &ispyb_pool)
        .await
        .unwrap();
    let app = Router::new()
        .route("/bundle.tar.gz", get(bundle_endpoint))
        .with_state(current_bundle.clone())
        .route_layer(RequireBearerLayer::new(args.require_token))
        .route("/healthz", get(health_endpoint))
        .fallback(fallback_endpoint)
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::new().level(tracing::Level::INFO))
                .on_request(DefaultOnRequest::default().level(tracing::Level::INFO))
                .on_response(DefaultOnResponse::new().level(tracing::Level::INFO))
                .on_failure(DefaultOnFailure::new().level(tracing::Level::INFO)),
        );

    let mut tasks = tokio::task::JoinSet::new();
    tasks.spawn(update_bundle(
        current_bundle,
        args.static_data,
        ispyb_pool,
        args.polling_interval.into(),
    ));
    tasks.spawn(serve_endpoints(args.port, app));
    tasks.join_next().await.unwrap().unwrap()
}

/// Sets up Logging & Tracing using jaeger if available
fn setup_telemetry(
    log_level: tracing::Level,
    otel_collector_url: Option<Url>,
) -> Result<(), anyhow::Error> {
    let level_filter = tracing_subscriber::filter::LevelFilter::from_level(log_level);
    let log_layer = tracing_subscriber::fmt::layer();
    let service_name_resource = opentelemetry_sdk::Resource::new(vec![
        opentelemetry::KeyValue::new(
            opentelemetry_semantic_conventions::resource::SERVICE_NAME,
            built_info::PKG_NAME,
        ),
        opentelemetry::KeyValue::new(
            opentelemetry_semantic_conventions::resource::SERVICE_VERSION,
            built_info::PKG_VERSION,
        ),
    ]);
    let (metrics_layer, tracing_layer) = if let Some(otel_collector_url) = otel_collector_url {
        (
            Some(tracing_opentelemetry::MetricsLayer::new(
                opentelemetry_otlp::new_pipeline()
                    .metrics(opentelemetry_sdk::runtime::Tokio)
                    .with_exporter(
                        opentelemetry_otlp::new_exporter()
                            .tonic()
                            .with_endpoint(otel_collector_url.clone()),
                    )
                    .with_resource(service_name_resource.clone())
                    .with_period(Duration::from_secs(10))
                    .build()?,
            )),
            Some(
                tracing_opentelemetry::layer().with_tracer(
                    opentelemetry_otlp::new_pipeline()
                        .tracing()
                        .with_exporter(
                            opentelemetry_otlp::new_exporter()
                                .tonic()
                                .with_endpoint(otel_collector_url),
                        )
                        .with_trace_config(
                            opentelemetry_sdk::trace::config().with_resource(service_name_resource),
                        )
                        .install_batch(opentelemetry_sdk::runtime::Tokio)?,
                ),
            ),
        )
    } else {
        (None, None)
    };

    tracing_subscriber::Registry::default()
        .with(level_filter)
        .with(log_layer)
        .with(metrics_layer)
        .with(tracing_layer)
        .init();

    Ok(())
}

/// Creates a connection pool to the ISPyB instance at the provided [`Url`]
#[instrument]
async fn connect_ispyb(database_url: Url) -> Result<MySqlPool, sqlx::Error> {
    tracing::info!("Establishing connection with ISPyB");
    let connection = MySqlPoolOptions::new().connect(database_url.as_str()).await;
    tracing::info!("Connection established wiht ISPyB");
    connection
}

/// Fetches the initial [`Bundle`] from ISPyB and any static files, and produces the corresponding
/// [`BundleFile`]
#[instrument]
async fn fetch_initial_bundle(
    static_data: &[Pattern],
    ispyb_pool: &MySqlPool,
) -> Result<Arc<RwLock<BundleFile<NoMetadata>>>, anyhow::Error> {
    tracing::info!("Fetching initial bundle");
    let bundle = Arc::new(RwLock::new(BundleFile::try_from(
        Bundle::fetch(NoMetadata, static_data, ispyb_pool)
            .await
            .unwrap(),
    )?));
    tracing::info!(
        "Using bundle with revison: {}",
        bundle.as_ref().read().await.bundle.revision()
    );
    Ok(bundle)
}

/// Bind to the provided socket address and serve the application endpoints
async fn serve_endpoints(port: u16, app: Router) {
    let socket_addr = SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, port));
    let listener = TcpListener::bind(socket_addr).await.unwrap();
    tracing::info!("Serving HTTP API on {}", socket_addr);
    axum::serve(listener, app).await.unwrap()
}

/// Periodically update the bundle with new data from ISPyB and any static files matching the given
/// glob patterns.
async fn update_bundle(
    current_bundle: impl AsRef<RwLock<BundleFile<NoMetadata>>>,
    static_data: Vec<Pattern>,
    ispyb_pool: MySqlPool,
    polling_interval: Duration,
) {
    let mut next_fetch = Instant::now().add(polling_interval);

    loop {
        sleep_until(next_fetch).await;
        next_fetch = next_fetch.add(polling_interval);
        tracing::info!("Updating bundle");
        let bundle = Bundle::fetch(NoMetadata, &static_data, &ispyb_pool)
            .await
            .unwrap();
        let bundle_file = BundleFile::try_from(bundle).unwrap();
        let old_revision = current_bundle
            .as_ref()
            .read()
            .await
            .bundle
            .revision()
            .to_owned();
        *current_bundle.as_ref().write().await = bundle_file;
        tracing::info!(
            "Updated bundle from {} to {}",
            old_revision,
            current_bundle.as_ref().read().await.bundle.revision()
        );
    }
}

/// Returns the Open Policy Agent bundle in gzipped tar format
///
/// ETag matching is supported via the 'If-None-Match' header, requests containing this header will not recieve any data if it matches the current bundle version
async fn bundle_endpoint(
    State(current_bundle): State<CurrentBundle>,
    if_none_match: Option<TypedHeader<IfNoneMatch>>,
) -> impl IntoResponse {
    let etag = ETag::from_str(&format!(
        r#""{}""#,
        current_bundle.as_ref().read().await.bundle.revision()
    ))
    .unwrap();
    let mut headers = HeaderMap::new();
    headers.typed_insert(etag.clone());
    tracing::info!(
        "Request had If-None-Match of {:?}, current ETag is {:?}",
        if_none_match,
        etag
    );
    match if_none_match {
        Some(TypedHeader(if_none_match)) if !if_none_match.precondition_passes(&etag) => {
            (StatusCode::NOT_MODIFIED, headers, Bytes::new())
        }
        _ => (
            StatusCode::OK,
            headers,
            current_bundle.as_ref().read().await.file.clone(),
        ),
    }
}

/// Returns an HTTP 200 response when requested.
///
/// Failures in the bundle update and serialization result in service crash, so ability to serve this endpoint implies liveness
async fn health_endpoint() -> impl IntoResponse {
    StatusCode::OK
}

/// Returns a HTTP 404 status code when a non-existant route is queried
async fn fallback_endpoint() -> impl IntoResponse {
    StatusCode::NOT_FOUND
}

/// Outputs the bundle schema as a set of files or to standard output
fn bundle_schema(args: BundleSchemaArgs) {
    let schemas = Bundle::<NoMetadata>::schemas()
        .into_iter()
        .map(|(name, schema)| (name, serde_json::to_string_pretty(&schema).unwrap()));
    if let Some(path) = args.path {
        for (name, schema) in schemas {
            let mut schema_file =
                File::create(path.clone().join(name).with_extension("json")).unwrap();
            schema_file.write_all(schema.as_bytes()).unwrap();
        }
    } else {
        println!(
            "{}",
            schemas
                .map(|(_, schema)| schema)
                .collect::<Vec<_>>()
                .join("\n\n---\n\n")
        )
    }
}
