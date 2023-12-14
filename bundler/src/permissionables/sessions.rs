use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;

#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize)]
pub struct Sessions(BTreeMap<String, Vec<(u32, u32)>>);

impl Sessions {
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            SessionRow,
            "
            SELECT
                login as fed_id,
                proposalId as proposal_id,
                visit_number
            FROM Session_has_Person
                INNER JOIN BLSession USING (sessionId)
                INNER JOIN Person USING (personId)
            UNION
            SELECT
                login as fed_id,
                BLSession.proposalId as proposal_id,
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
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(session_rows.into_iter().collect())
    }
}

struct SessionRow {
    fed_id: Option<String>,
    proposal_id: u32,
    visit_number: Option<u32>,
}

impl FromIterator<SessionRow> for Sessions {
    fn from_iter<T: IntoIterator<Item = SessionRow>>(iter: T) -> Self {
        let mut sessions = Self::default();
        for session_row in iter {
            if let Some(fed_id) = session_row.fed_id {
                sessions.0.entry(fed_id).or_default().push((
                    session_row.proposal_id,
                    session_row.visit_number.unwrap_or_default(),
                ));
            }
        }
        sessions
    }
}

#[cfg(test)]
mod tests {
    use super::Sessions;
    use sqlx::MySqlPool;
    use std::collections::{BTreeMap, BTreeSet};

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let expected = Sessions(BTreeMap::new());
        assert_eq!(expected, sessions);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../tests/fixtures",
            scripts("session_membership", "beamline_sessions", "persons")
        )
    )]
    async fn fetch_direct(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert("foo".to_string(), vec![(30, 10), (30, 11)]);
        expected.insert("bar".to_string(), vec![(31, 10)]);
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
            path = "../../tests/fixtures",
            scripts("proposal_membership", "beamline_sessions", "persons")
        )
    )]
    async fn fetch_indirect(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            "foo".to_string(),
            BTreeSet::from([(30, 10), (30, 11), (30, 12), (31, 10), (31, 11)]),
        );
        expected.insert(
            "bar".to_string(),
            BTreeSet::from([(30, 10), (30, 11), (30, 12)]),
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
            path = "../../tests/fixtures",
            scripts(
                "session_membership",
                "proposal_membership",
                "beamline_sessions",
                "persons"
            )
        )
    )]
    async fn fetch_both(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            "foo".to_string(),
            BTreeSet::from([(30, 10), (30, 11), (30, 12), (31, 10), (31, 11)]),
        );
        expected.insert(
            "bar".to_string(),
            BTreeSet::from([(30, 10), (30, 11), (30, 12), (31, 10)]),
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
