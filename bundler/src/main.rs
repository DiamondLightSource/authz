mod bundle;

use crate::bundle::{Bundle, NoMetadata};
use axum::{
    body::Bytes,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    serve, Router,
};
use clap::Parser;
use std::net::{Ipv4Addr, SocketAddr, SocketAddrV4};
use tokio::net::TcpListener;
use tracing_subscriber::EnvFilter;

#[derive(Debug, Parser)]
#[command(author, version, about, long_about= None)]
struct Cli {
    #[arg(short, long, env = "BUNDLER_PORT", default_value_t = 80)]
    port: u16,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let args = Cli::parse();

    let tracing_subscriber = tracing_subscriber::FmtSubscriber::builder()
        .with_env_filter(EnvFilter::from_default_env())
        .finish();
    tracing::subscriber::set_global_default(tracing_subscriber).unwrap();

    let app = Router::new().route("/bundle.tar.gz", get(bundle_endpoint));
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

async fn bundle_endpoint() -> Result<Bytes, BundleError> {
    let bundle = Bundle::new(NoMetadata);
    Ok(bundle.to_tar_gz()?.into())
}
