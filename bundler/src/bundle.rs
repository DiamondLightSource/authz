use flate2::{write::GzEncoder, Compression};
use schemars::{schema::RootSchema, schema_for, JsonSchema};
use serde::Serialize;
use sqlx::MySqlPool;
use std::{
    collections::{hash_map::DefaultHasher, BTreeMap, HashMap},
    ffi::OsStr,
    fmt::{Debug, Display},
    hash::{Hash, Hasher},
    path::Path,
};
use tar::Header;
use tokio::try_join;
use tracing::{instrument, trace, warn};

use crate::permissionables::{
    beamlines::Beamlines, proposals::Proposals, sessions::Sessions, subjects::Subjects,
};

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
    /// A mapping of subjects to their various attributes
    subjects: Subjects,
    /// A mapping of sessions to their various attributes
    sessions: Sessions,
    /// A mapping of proposals to their various attributes
    proposals: Proposals,
    /// A mapping of beamlines to their various attributes
    beamlines: Beamlines,
    /// A map (name to data) of static files to include in the bundle
    static_data: HashMap<String, Vec<u8>>,
}

/// The prefix applied to data files in the bundle. Open Policy Agent does not support loading bundles with overlapping prefixes
const BUNDLE_PREFIX: &str = "diamond/data";

impl<Metadata> Bundle<Metadata>
where
    Metadata: Debug + Hash + Serialize,
{
    /// Creates a [`Bundle`] from known [`Subjects`]
    pub fn new(
        metadata: Metadata,
        subjects: Subjects,
        sessions: Sessions,
        proposals: Proposals,
        beamlines: Beamlines,
        static_data: HashMap<String, Vec<u8>>,
    ) -> Self {
        let mut hasher = DefaultHasher::new();
        metadata.hash(&mut hasher);
        subjects.hash(&mut hasher);
        sessions.hash(&mut hasher);
        proposals.hash(&mut hasher);
        beamlines.hash(&mut hasher);
        for entry in &static_data {
            entry.hash(&mut hasher);
        }
        let hash = hasher.finish();

        Self {
            manifest: Manifest {
                revision: format!("{}:{}", crate::built_info::PKG_VERSION, hash),
                roots: vec![BUNDLE_PREFIX.to_string()],
                wasm: vec![],
                metadata,
            },
            subjects,
            sessions,
            proposals,
            beamlines,
            static_data,
        }
    }

    /// Fetches [`Subjects`] from ISPyB and constructs a [`Bundle`]
    #[instrument(name = "fetch_bundle")]
    pub async fn fetch(
        metadata: Metadata,
        static_data_directory: Option<&Path>,
        ispyb_pool: &MySqlPool,
    ) -> Result<Self, sqlx::Error> {
        let (subjects, sessions, proposals, beamlines) = try_join!(
            Subjects::fetch(ispyb_pool),
            Sessions::fetch(ispyb_pool),
            Proposals::fetch(ispyb_pool),
            Beamlines::fetch(ispyb_pool),
        )?;
        let static_data = match static_data_directory {
            Some(dir) => static_data(dir).await?,
            None => HashMap::default(),
        };
        Ok(Self::new(
            metadata,
            subjects,
            sessions,
            proposals,
            beamlines,
            static_data,
        ))
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

        let subjects = serde_json::to_vec(&self.subjects)?;
        let mut subjects_header = Header::from_bytes(&subjects);
        bundle_builder.append_data(
            &mut subjects_header,
            format!("{BUNDLE_PREFIX}/subjects/data.json"),
            subjects.as_slice(),
        )?;

        let sessions = serde_json::to_vec(&self.sessions)?;
        let mut sessions_header = Header::from_bytes(&sessions);
        bundle_builder.append_data(
            &mut sessions_header,
            format!("{BUNDLE_PREFIX}/sessions/data.json"),
            sessions.as_slice(),
        )?;

        let proposals = serde_json::to_vec(&self.proposals)?;
        let mut proposals_header = Header::from_bytes(&proposals);
        bundle_builder.append_data(
            &mut proposals_header,
            format!("{BUNDLE_PREFIX}/proposals/data.json"),
            proposals.as_slice(),
        )?;

        let beamlines = serde_json::to_vec(&self.beamlines)?;
        let mut beamlines_header = Header::from_bytes(&beamlines);
        bundle_builder.append_data(
            &mut beamlines_header,
            format!("{BUNDLE_PREFIX}/beamlines/data.json"),
            beamlines.as_slice(),
        )?;

        for (name, data) in &self.static_data {
            let mut header = Header::from_bytes(data);
            bundle_builder.append_data(
                &mut header,
                format!("{BUNDLE_PREFIX}/{name}/data.json"),
                data.as_slice(),
            )?;
        }

        Ok(bundle_builder.into_inner()?.finish()?)
    }

    /// Produces a set of schemas associated with the data in the bundle
    pub fn schemas() -> BTreeMap<String, RootSchema> {
        BTreeMap::from([
            (Subjects::schema_name(), schema_for!(Subjects)),
            (Sessions::schema_name(), schema_for!(Sessions)),
            (Proposals::schema_name(), schema_for!(Proposals)),
            (Beamlines::schema_name(), schema_for!(Beamlines)),
        ])
    }
}

/// Read static data from files that should be included in the compiled bundle
async fn static_data(root: &Path) -> Result<HashMap<String, Vec<u8>>, std::io::Error> {
    let mut data = HashMap::new();
    let mut contents = tokio::fs::read_dir(root).await?;
    while let Some(entry) = contents.next_entry().await? {
        let path = entry.path();
        if !path.is_file() || !path.extension().is_some_and(|ext| ext == "json") {
            // Not explicitly a json file so ignore
            trace!("Skipping non file in static data directory: {path:?}");
            continue;
        }
        let name = path.file_stem();
        let Some(name) = name.and_then(OsStr::to_str) else {
            // Save having to think about non-utf8 in OPA rules
            trace!("Skipping non-utf8 static file: {name:?}");
            continue;
        };
        data.insert(name.to_string(), tokio::fs::read(&path).await?);
    }
    Ok(data)
}

/// Combination of possible errors when fetching data to create bundle
#[derive(Debug)]
pub enum BundleDataError {
    /// Error fetching data from database
    Sql(sqlx::Error),
    /// Error fetching data from file
    Static(std::io::Error),
}

impl From<sqlx::Error> for BundleDataError {
    fn from(value: sqlx::Error) -> Self {
        Self::Sql(value)
    }
}

impl From<std::io::Error> for BundleDataError {
    fn from(value: std::io::Error) -> Self {
        Self::Static(value)
    }
}

impl Display for BundleDataError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            BundleDataError::Sql(e) => write!(f, "Error reading dynamic data: {e}"),
            BundleDataError::Static(e) => write!(f, "Error reading static data: {e}"),
        }
    }
}

impl std::error::Error for BundleDataError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            BundleDataError::Sql(e) => Some(e),
            BundleDataError::Static(e) => Some(e),
        }
    }
}
