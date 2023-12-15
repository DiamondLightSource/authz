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
    serve, Router,
};
use axum_extra::TypedHeader;
use clap::Parser;
use headers::{ETag, HeaderMapExt, IfNoneMatch};
use require_bearer::RequireBearerLayer;
use serde::Serialize;
use sqlx::{mysql::MySqlPoolOptions, MySqlPool};
use std::{
    hash::Hash,
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
use tower_http::trace::TraceLayer;
use tracing_subscriber::util::SubscriberInitExt;
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
    Metadata: Hash + Serialize,
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

/// Bundler acts as a Open Policy Agent bundle server, providing permissionable data from the ISPyB database
#[derive(Debug, Parser)]
#[command(author, version, about, long_about= None)]
struct Cli {
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
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let args = Cli::parse();

    tracing_subscriber::FmtSubscriber::builder()
        .with_max_level(args.log_level)
        .finish()
        .init();

    let ispyb_pool = MySqlPoolOptions::new()
        .connect(args.database_url.as_str())
        .await
        .unwrap();
    let current_bundle = Arc::new(RwLock::new(
        BundleFile::try_from(Bundle::fetch(NoMetadata, &ispyb_pool).await.unwrap()).unwrap(),
    ));
    let app = Router::new()
        .route("/bundle.tar.gz", get(bundle_endpoint))
        .route_layer(RequireBearerLayer::new(args.require_token))
        .fallback(fallback_endpoint)
        .layer(TraceLayer::new_for_http())
        .with_state(current_bundle.clone());

    let mut tasks = tokio::task::JoinSet::new();
    tasks.spawn(update_bundle(
        current_bundle,
        ispyb_pool,
        args.polling_interval.into(),
    ));
    tasks.spawn(serve_app(args.port, app));
    tasks.join_next().await.unwrap().unwrap()
}

/// Bind to the provided socket address and serve the application endpoints
async fn serve_app(port: u16, app: Router) {
    let socket_addr = SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, port));
    let listener = TcpListener::bind(socket_addr).await.unwrap();
    serve(listener, app).await.unwrap()
}

/// Periodically update the bundle with new data from ISPyB
async fn update_bundle(
    current_bundle: impl AsRef<RwLock<BundleFile<NoMetadata>>>,
    ispyb_pool: MySqlPool,
    polling_interval: Duration,
) {
    let mut next_fetch = Instant::now().add(polling_interval);

    loop {
        sleep_until(next_fetch).await;
        next_fetch = next_fetch.add(polling_interval);
        let bundle = Bundle::fetch(NoMetadata, &ispyb_pool).await.unwrap();
        let bundle_file = BundleFile::try_from(bundle).unwrap();
        *current_bundle.as_ref().write().await = bundle_file;
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

/// Returns a HTTP 404 status code when a non-existant route is queried
async fn fallback_endpoint() -> impl IntoResponse {
    StatusCode::NOT_FOUND
}
