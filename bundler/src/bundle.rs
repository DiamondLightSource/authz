use crate::permissionables::{proposals::Proposals, sessions::Sessions};
use flate2::{write::GzEncoder, Compression};
use serde::Serialize;
use sqlx::MySqlPool;
use tar::Header;

#[derive(Debug, Serialize)]
struct WasmModule {
    pub entrypoint: String,
    pub module: String,
}

#[derive(Debug, Serialize)]
pub struct NoMetadata;

#[derive(Debug, Serialize)]
struct Manifest<Metadata>
where
    Metadata: Serialize,
{
    revision: String,
    roots: Vec<String>,
    wasm: Vec<WasmModule>,
    metadata: Metadata,
}

trait FromByteSlice {
    fn from_bytes(slice: &[u8]) -> Self;
}

impl FromByteSlice for Header {
    fn from_bytes(slice: &[u8]) -> Self {
        let mut header = Self::new_gnu();
        header.set_size(slice.len() as u64);
        header.set_cksum();
        header
    }
}

pub struct Bundle<Metadata>
where
    Metadata: Serialize,
{
    manifest: Manifest<Metadata>,
    proposals: Proposals,
    sessions: Sessions,
}

impl<Metadata> Bundle<Metadata>
where
    Metadata: Serialize,
{
    pub fn new(metadata: Metadata, proposals: Proposals, sessions: Sessions) -> Self {
        Self {
            manifest: Manifest {
                revision: "v0.1.0".to_string(),
                roots: vec!["diamond".to_string()],
                wasm: vec![],
                metadata,
            },
            proposals,
            sessions,
        }
    }

    pub async fn fetch(metadata: Metadata, ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposals = Proposals::fetch(ispyb_pool).await?;
        let sessions = Sessions::fetch(ispyb_pool).await?;
        Ok(Self::new(metadata, proposals, sessions))
    }

    pub fn to_tar_gz(&self) -> Result<Vec<u8>, anyhow::Error> {
        let mut bundle_builder = tar::Builder::new(GzEncoder::new(Vec::new(), Compression::best()));

        let manifest = serde_json::to_vec(&self.manifest)?;
        let mut manifest_header = Header::from_bytes(&manifest);
        bundle_builder.append_data(&mut manifest_header, ".manifest", manifest.as_slice())?;

        let proposals = serde_json::to_vec(&self.proposals)?;
        let mut proposals_header = Header::from_bytes(&proposals);
        bundle_builder.append_data(
            &mut proposals_header,
            "diamond/users/proposals.json",
            proposals.as_slice(),
        )?;

        let sessions = serde_json::to_vec(&self.sessions)?;
        let mut sessions_header = Header::from_bytes(&sessions);
        bundle_builder.append_data(
            &mut sessions_header,
            "diamond/users/sessions.json",
            sessions.as_slice(),
        )?;

        Ok(bundle_builder.into_inner()?.finish()?)
    }
}
