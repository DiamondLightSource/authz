use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::HashMap;

#[derive(Debug, PartialEq, Eq, Serialize)]
pub struct Sessions(HashMap<u32, Vec<u32>>);

impl Sessions {
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            SessionRow,
            "
            SELECT
                personId as person_id,
                sessionId as session_id
            FROM Session_has_Person
            UNION
            SELECT
                personId as person_id,
                sessionId as session_id
            FROM (
                    SELECT
                        DISTINCT proposalId,
                        personId
                    FROM
                        ProposalHasPerson
                ) AS UniqueProposalHasPerson
                CROSS JOIN BLSession
            WHERE
                UniqueProposalHasPerson.proposalId = BLSession.proposalId
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(session_rows.into_iter().collect())
    }
}

struct SessionRow {
    person_id: u32,
    session_id: u32,
}

impl FromIterator<SessionRow> for Sessions {
    fn from_iter<T: IntoIterator<Item = SessionRow>>(iter: T) -> Self {
        let mut sessions = HashMap::<u32, Vec<u32>>::default();

        for session_row in iter {
            sessions
                .entry(session_row.person_id)
                .or_default()
                .push(session_row.session_id);
        }

        Self(sessions)
    }
}

#[cfg(test)]
mod tests {
    use super::Sessions;
    use sqlx::MySqlPool;
    use std::collections::HashMap;

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let expected = Sessions(HashMap::new());
        assert_eq!(expected, sessions);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(path = "../../tests/fixtures", scripts("session_membership"))
    )]
    async fn fetch_direct(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = Sessions(HashMap::new());
        expected.0.insert(10, vec![1000, 1001]);
        expected.0.insert(11, vec![1000]);
        assert_eq!(expected, sessions);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../tests/fixtures",
            scripts("proposal_membership", "beamline_sessions")
        )
    )]
    async fn fetch_indirect(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = Sessions(HashMap::new());
        expected.0.insert(10, vec![1002, 1003, 1004]);
        expected.0.insert(11, vec![1002, 1003]);
        assert_eq!(expected, sessions);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../tests/fixtures",
            scripts("session_membership", "proposal_membership", "beamline_sessions")
        )
    )]
    async fn fetch_both(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = Sessions(HashMap::new());
        expected.0.insert(10, vec![1000, 1001, 1002, 1003, 1004]);
        expected.0.insert(11, vec![1000, 1002, 1003]);
        assert_eq!(expected, sessions);
    }
}
