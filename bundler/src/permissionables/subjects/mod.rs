/// A mapping of subjects to their permissions, via roles
mod permissions;
/// A mapping of subjects to their proposals
mod proposals;
/// A mapping of subjects to their sessions, possibly via proposals
mod sessions;

use self::{
    permissions::SubjectPermissions, proposals::SubjectProposals, sessions::SubjectSessions,
};
use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::MySqlPool;
use std::collections::{BTreeMap, HashSet};
use tokio::try_join;
use tracing::instrument;

/// A mapping of subjects to their various attributes
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Subjects(BTreeMap<String, Subject>);

/// The various attributes of a subject
#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Subject {
    /// The permissions given to a subject
    permissions: Vec<String>,
    /// The proposals the subject is associated with
    proposals: Vec<u32>,
    /// The sessions the subject is associated with
    sessions: Vec<u32>,
}

impl Subjects {
    #[instrument(name = "fetch_subjects")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let (mut permissions, mut proposals, mut sessions) = try_join!(
            SubjectPermissions::fetch(ispyb_pool),
            SubjectProposals::fetch(ispyb_pool),
            SubjectSessions::fetch(ispyb_pool)
        )?;

        let mut subjects = Self::default();
        for subject in permissions
            .keys()
            .chain(proposals.keys())
            .chain(sessions.keys())
            .cloned()
            .collect::<HashSet<_>>()
        {
            subjects.insert(
                subject.to_owned(),
                Subject {
                    permissions: permissions.remove(&subject).clone().unwrap_or_default(),
                    proposals: proposals.remove(&subject).unwrap_or_default(),
                    sessions: sessions.remove(&subject).unwrap_or_default(),
                },
            );
        }

        Ok(subjects)
    }
}
