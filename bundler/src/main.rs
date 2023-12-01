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
use sqlx::{mysql::MySqlPoolOptions, MySqlPool};
use std::net::{Ipv4Addr, SocketAddr, SocketAddrV4};
use tokio::net::TcpListener;
use tower_http::trace::TraceLayer;
use tracing_subscriber::util::SubscriberInitExt;
use url::Url;

#[derive(Debug, Parser)]
#[command(author, version, about, long_about= None)]
struct Cli {
    #[arg(short, long, env = "BUNDLER_PORT", default_value_t = 80)]
    port: u16,
    #[arg(long, env = "BUNDLER_DATABASE_URL")]
    database_url: Url,
    #[arg(long, env = "BUNDLER_LOG_LEVEL", default_value_t = tracing::Level::INFO)]
    log_level: tracing::Level,
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
    let app = Router::new()
        .route("/bundle.tar.gz", get(bundle_endpoint))
        .layer(TraceLayer::new_for_http())
        .with_state(ispyb_pool);
    let socket_addr = SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, args.port));
    let listener = TcpListener::bind(socket_addr).await.unwrap();
    serve(listener, app).await.unwrap();
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

async fn bundle_endpoint(State(ispyb_pool): State<MySqlPool>) -> Result<Bytes, BundleError> {
    let bundle = Bundle::fetch(NoMetadata, &ispyb_pool).await?;
    Ok(bundle.to_tar_gz()?.into())
}
