use axum::{
    body::Bytes,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    serve, Router,
};
use clap::Parser;
use flate2::{write::GzEncoder, Compression};
use std::net::{Ipv4Addr, SocketAddr, SocketAddrV4};
use tar::Header;
use tokio::net::TcpListener;
use tracing_subscriber::EnvFilter;

#[derive(Debug, Parser)]
#[command(author, version, about, long_about= None)]
struct Cli {
    #[arg(short, long, default_value_t = 80)]
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
    let mut bundle_builder = tar::Builder::new(GzEncoder::new(Vec::new(), Compression::default()));

    let data = r#"{"hello":"world"}"#.as_bytes();
    let mut data_header = Header::new_gnu();
    data_header.set_size(data.len() as u64);
    data_header.set_cksum();

    bundle_builder.append_data(&mut data_header, "diamond/data.json", data)?;

    Ok(bundle_builder.into_inner()?.finish()?.into())
}
