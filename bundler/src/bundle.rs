use crate::permissionables::{permissions::Permissions, proposals::Proposals, sessions::Sessions};
use flate2::{write::GzEncoder, Compression};
use schemars::{schema::RootSchema, schema_for, JsonSchema};
use serde::Serialize;
use sqlx::MySqlPool;
use std::{
    collections::{hash_map::DefaultHasher, BTreeMap},
    hash::{Hash, Hasher},
};
use tar::Header;

/// A compiled Web Assembly module
#[derive(Debug, Serialize)]
struct WasmModule {
    /// The entrypoint of the bundle
    pub entrypoint: String,
    /// The path to the WebAssembly module
    pub module: String,
}

/// A placeholder to be used when no metadata is required
#[derive(Debug, Hash, Serialize)]
pub struct NoMetadata;

/// The manifest file, which contains data about the bundle and optional additonal metadata
#[derive(Debug, Serialize)]
struct Manifest<Metadata>
where
    Metadata: Serialize,
{
    /// The revision of the bundle, comprising of the crate version number and the bundle hash
    revision: String,
    /// The directory prefixes of the data contained within the bundle
    roots: Vec<String>,
    /// A set of WebAssembly modules included in the bundle
    wasm: Vec<WasmModule>,
    /// Optional extra metadata
    metadata: Metadata,
}

/// An extension trait used to implement header creation from byte slices
trait FromByteSlice {
    #[allow(clippy::missing_docs_in_private_items)]
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

/// The contents of the Open Policy Agent bundle
pub struct Bundle<Metadata>
where
    Metadata: Serialize,
{
    /// The manifest file, which contains data about the bundle and optional additonal metadata
    manifest: Manifest<Metadata>,
    /// A mapping of users to their proposals
    proposals: Proposals,
    /// A mapping of users to their sessions
    sessions: Sessions,
    /// A mapping of users to their permissions via groups
    permissions: Permissions,
}

/// The prefix applied to data files in the bundle. Open Policy Agent does not support loading bundles with overlapping prefixes
const BUNDLE_PREFIX: &str = "diamond/data";

impl<Metadata> Bundle<Metadata>
where
    Metadata: Hash + Serialize,
{
    /// Creates a [`Bundle`] from known [`Proposals`], [`Sessions`] and [`Permissions`]
    pub fn new(
        metadata: Metadata,
        proposals: Proposals,
        sessions: Sessions,
        permissions: Permissions,
    ) -> Self {
        let mut hasher = DefaultHasher::new();
        metadata.hash(&mut hasher);
        proposals.hash(&mut hasher);
        sessions.hash(&mut hasher);
        permissions.hash(&mut hasher);
        let hash = hasher.finish();

        Self {
            manifest: Manifest {
                revision: format!("{}:{}", crate::built_info::PKG_VERSION, hash),
                roots: vec![BUNDLE_PREFIX.to_string()],
                wasm: vec![],
                metadata,
            },
            proposals,
            sessions,
            permissions,
        }
    }

    /// Fetches [`Proposals`], [`Sessions`] and [`Permissions`] for ISPyB and constructs a [`Bundle`]
    pub async fn fetch(metadata: Metadata, ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposals = Proposals::fetch(ispyb_pool).await?;
        let sessions = Sessions::fetch(ispyb_pool).await?;
        let permissions = Permissions::fetch(ispyb_pool).await?;
        Ok(Self::new(metadata, proposals, sessions, permissions))
    }

    /// The current revision of the bundle, as recorded in the [`Manifest`]
    pub fn revision(&self) -> &str {
        &self.manifest.revision
    }

    /// Serializes the [`Bundle`] as a gzipped tar archive, for import by Open Policy Agent
    pub fn to_tar_gz(&self) -> Result<Vec<u8>, anyhow::Error> {
        let mut bundle_builder = tar::Builder::new(GzEncoder::new(Vec::new(), Compression::best()));

        let manifest = serde_json::to_vec(&self.manifest)?;
        let mut manifest_header = Header::from_bytes(&manifest);
        bundle_builder.append_data(&mut manifest_header, ".manifest", manifest.as_slice())?;

        let proposals = serde_json::to_vec(&self.proposals)?;
        let mut proposals_header = Header::from_bytes(&proposals);
        bundle_builder.append_data(
            &mut proposals_header,
            format!("{BUNDLE_PREFIX}/users/proposals/data.json"),
            proposals.as_slice(),
        )?;

        let sessions = serde_json::to_vec(&self.sessions)?;
        let mut sessions_header = Header::from_bytes(&sessions);
        bundle_builder.append_data(
            &mut sessions_header,
            format!("{BUNDLE_PREFIX}/users/sessions/data.json"),
            sessions.as_slice(),
        )?;

        let permissions = serde_json::to_vec(&self.permissions)?;
        let mut permissions_header = Header::from_bytes(&permissions);
        bundle_builder.append_data(
            &mut permissions_header,
            format!("{BUNDLE_PREFIX}/users/permissions/data.json"),
            permissions.as_slice(),
        )?;

        Ok(bundle_builder.into_inner()?.finish()?)
    }

    /// Produces a set of schemas associated with the data in the bundle
    pub fn schemas() -> BTreeMap<String, RootSchema> {
        BTreeMap::from([
            (Proposals::schema_name(), schema_for!(Proposals)),
            (Sessions::schema_name(), schema_for!(Sessions)),
            (Permissions::schema_name(), schema_for!(Permissions)),
        ])
    }
}
