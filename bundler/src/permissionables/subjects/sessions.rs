use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of subjects to their sessions, possibly via proposals
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct SubjectSessions(BTreeMap<String, Vec<u32>>);

impl SubjectSessions {
    /// Fetches [`Sessions`] from ISPyB
    #[instrument(name = "fetch_subject_sessions")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            RawSessionRow,
            "
            SELECT
                login as subject,
                sessionId as session_id
            FROM
                Person
                INNER JOIN Session_has_Person USING (personId)
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(session_rows.into_iter().collect())
    }
}

/// A row from ISPyB detailing the sessions a subject is associcated with
struct SessionRow {
    /// The unique identifier of the subject
    subject: String,
    /// An opaque identifier of the session
    session_id: u32,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawSessionRow {
    subject: Option<String>,
    session_id: u32,
}

impl TryFrom<RawSessionRow> for SessionRow {
    type Error = anyhow::Error;

    fn try_from(value: RawSessionRow) -> Result<Self, Self::Error> {
        Ok(Self {
            subject: value.subject.ok_or(anyhow::anyhow!("FedId was NULL"))?,
            session_id: value.session_id,
        })
    }
}

impl FromIterator<RawSessionRow> for SubjectSessions {
    fn from_iter<T: IntoIterator<Item = RawSessionRow>>(iter: T) -> Self {
        let mut sessions = Self::default();
        for session_row in iter {
            if let Ok(session_row) = SessionRow::try_from(session_row) {
                sessions
                    .entry(session_row.subject)
                    .or_default()
                    .push(session_row.session_id);
            }
        }
        sessions
    }
}

#[cfg(test)]
mod tests {
    use super::SubjectSessions;
    use sqlx::MySqlPool;
    use std::collections::BTreeMap;

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let sessions = SubjectSessions::fetch(&ispyb_pool).await.unwrap();
        let expected = SubjectSessions(BTreeMap::new());
        assert_eq!(expected, sessions);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../../tests/fixtures",
            scripts("session_membership", "persons")
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let sessions = SubjectSessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert("foo".to_string(), vec![40, 41]);
        expected.insert("bar".to_string(), vec![43]);
        assert_eq!(expected, sessions.0);
    }
}
