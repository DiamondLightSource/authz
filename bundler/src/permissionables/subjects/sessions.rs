use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of subjects to their sessions, possibly via proposals
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct SubjectSessions(BTreeMap<String, Vec<(u32, u32)>>);

impl SubjectSessions {
    /// Fetches [`Sessions`] from ISPyB
    #[instrument(name = "fetch_sessions")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            RawSessionRow,
            "
            SELECT
                login as subject,
                proposalNumber AS proposal_number,
                visit_number
            FROM
                Session_has_Person
                INNER JOIN BLSession USING (sessionId)
                INNER JOIN Person USING (personId)
                INNER JOIN Proposal USING (proposalId)
            WHERE
                Proposal.externalId IS NOT NULL
            UNION
            SELECT
                login as subject,
                proposalNumber AS proposal_number,
                visit_number
            FROM (
                    SELECT
                        DISTINCT proposalId,
                        personId
                    FROM
                        ProposalHasPerson
                ) AS UniqueProposalHasPerson
                CROSS JOIN BLSession USING (proposalId)
                INNER JOIN Person USING (personId)
                INNER JOIN Proposal USING (proposalId)
            WHERE
                Proposal.externalId IS NOT NULL
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
    /// The proposal number of the visit
    proposal_number: u32,
    /// The number of the visit within the proposal
    visit_number: u32,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawSessionRow {
    subject: Option<String>,
    proposal_number: Option<String>,
    visit_number: Option<u32>,
}

impl TryFrom<RawSessionRow> for SessionRow {
    type Error = anyhow::Error;

    fn try_from(value: RawSessionRow) -> Result<Self, Self::Error> {
        Ok(Self {
            subject: value.subject.ok_or(anyhow::anyhow!("FedId was NULL"))?,
            proposal_number: value
                .proposal_number
                .ok_or(anyhow::anyhow!("Proposal number was NULL"))?
                .parse()?,
            visit_number: value.visit_number.unwrap_or_default(),
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
                    .push((session_row.proposal_number, session_row.visit_number));
            }
        }
        sessions
    }
}

#[cfg(test)]
mod tests {
    use super::SubjectSessions;
    use sqlx::MySqlPool;
    use std::collections::{BTreeMap, BTreeSet};

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
            scripts("session_membership", "beamline_sessions", "persons", "proposals")
        )
    )]
    async fn fetch_direct(ispyb_pool: MySqlPool) {
        let sessions = SubjectSessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert("foo".to_string(), vec![(10030, 10), (10030, 11)]);
        expected.insert("bar".to_string(), vec![(10031, 10)]);
        assert_eq!(
            expected,
            sessions
                .0
                .into_iter()
                .map(|(k, v)| (k, v.into_iter().collect()))
                .collect()
        );
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../../tests/fixtures",
            scripts("proposal_membership", "beamline_sessions", "persons", "proposals")
        )
    )]
    async fn fetch_indirect(ispyb_pool: MySqlPool) {
        let sessions = SubjectSessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            "foo".to_string(),
            BTreeSet::from([
                (10030, 10),
                (10030, 11),
                (10030, 12),
                (10031, 10),
                (10031, 11),
            ]),
        );
        expected.insert(
            "bar".to_string(),
            BTreeSet::from([(10030, 10), (10030, 11), (10030, 12)]),
        );
        assert_eq!(
            expected,
            sessions
                .0
                .into_iter()
                .map(|(k, v)| (k, v.into_iter().collect()))
                .collect()
        );
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../../tests/fixtures",
            scripts(
                "session_membership",
                "proposal_membership",
                "beamline_sessions",
                "persons",
                "proposals"
            )
        )
    )]
    async fn fetch_both(ispyb_pool: MySqlPool) {
        let sessions = SubjectSessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            "foo".to_string(),
            BTreeSet::from([
                (10030, 10),
                (10030, 11),
                (10030, 12),
                (10031, 10),
                (10031, 11),
            ]),
        );
        expected.insert(
            "bar".to_string(),
            BTreeSet::from([(10030, 10), (10030, 11), (10030, 12), (10031, 10)]),
        );
        assert_eq!(
            expected,
            sessions
                .0
                .into_iter()
                .map(|(k, v)| (k, v.into_iter().collect()))
                .collect()
        );
    }
}
