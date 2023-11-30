use crate::permissionables::proposals::Proposals;
use flate2::{write::GzEncoder, Compression};
use serde::Serialize;
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
}

impl<Metadata> Bundle<Metadata>
where
    Metadata: Serialize,
{
    pub fn new(metadata: Metadata, proposals: Proposals) -> Self {
        Self {
            manifest: Manifest {
                revision: "v0.1.0".to_string(),
                roots: vec!["diamond".to_string()],
                wasm: vec![],
                metadata,
            },
            proposals,
        }
    }

    pub fn to_tar_gz(&self) -> Result<Vec<u8>, anyhow::Error> {
        let mut bundle_builder =
            tar::Builder::new(GzEncoder::new(Vec::new(), Compression::default()));

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

        Ok(bundle_builder.into_inner()?.finish()?)
    }
}
