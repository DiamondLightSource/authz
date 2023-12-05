mod bundle;
mod permissionables;

use crate::bundle::{Bundle, NoMetadata};
use axum::{
    body::Bytes,
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    serve, Router,
};
use clap::Parser;
use serde::Serialize;
use sqlx::{mysql::MySqlPoolOptions, MySqlPool};
use std::{
    net::{Ipv4Addr, SocketAddr, SocketAddrV4},
    ops::Add,
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

struct BundleFile<Metadata>
where
    Metadata: Serialize,
{
    _bundle: Bundle<Metadata>,
    file: Bytes,
}

impl<Metadata> TryFrom<Bundle<Metadata>> for BundleFile<Metadata>
where
    Metadata: Serialize,
{
    type Error = anyhow::Error;

    fn try_from(bundle: Bundle<Metadata>) -> Result<Self, Self::Error> {
        Ok(Self {
            file: bundle.to_tar_gz()?.into(),
            _bundle: bundle,
        })
    }
}

type CurrentBundle = Arc<RwLock<BundleFile<NoMetadata>>>;

#[derive(Debug, Parser)]
#[command(author, version, about, long_about= None)]
struct Cli {
    #[arg(short, long, env = "BUNDLER_PORT", default_value_t = 80)]
    port: u16,
    #[arg(long, env = "BUNDLER_DATABASE_URL")]
    database_url: Url,
    #[arg(long, env = "BUNDLER_LOG_LEVEL", default_value_t = tracing::Level::INFO)]
    log_level: tracing::Level,
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

    let ispyb_pool = Arc::new(
        MySqlPoolOptions::new()
            .connect(args.database_url.as_str())
            .await
            .unwrap(),
    );
    let current_bundle = Arc::new(RwLock::new(
        BundleFile::try_from(Bundle::fetch(NoMetadata, &ispyb_pool).await.unwrap()).unwrap(),
    ));
    tokio::task::spawn(update_bundle(
        current_bundle.clone(),
        ispyb_pool.clone(),
        args.polling_interval.into(),
    ));
    let app = Router::new()
        .route("/bundle.tar.gz", get(bundle_endpoint))
        .layer(TraceLayer::new_for_http())
        .with_state(current_bundle);
    let socket_addr = SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, args.port));
    let listener = TcpListener::bind(socket_addr).await.unwrap();
    serve(listener, app).await.unwrap();
}

async fn update_bundle(
    current_bundle: impl AsRef<RwLock<BundleFile<NoMetadata>>>,
    ispyb_pool: impl AsRef<MySqlPool> + Clone,
    polling_interval: Duration,
) {
    let mut next_fetch = Instant::now().add(polling_interval);
    loop {
        sleep_until(next_fetch).await;
        next_fetch = next_fetch.add(polling_interval);
        let bundle = Bundle::fetch(NoMetadata, ispyb_pool.clone().as_ref())
            .await
            .unwrap();
        let bundle_file = BundleFile::try_from(bundle).unwrap();
        *current_bundle.as_ref().write().await = bundle_file;
    }
}

struct BundleError(anyhow::Error);

impl<E: Into<anyhow::Error>> From<E> for BundleError {
    fn from(err: E) -> Self {
        Self(err.into())
    }
}

impl IntoResponse for BundleError {
    fn into_response(self) -> Response {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("Something went wrong: {}", self.0),
        )
            .into_response()
    }
}

async fn bundle_endpoint(
    State(current_bundle): State<CurrentBundle>,
) -> Result<Bytes, BundleError> {
    Ok(current_bundle.as_ref().read().await.file.clone())
}
