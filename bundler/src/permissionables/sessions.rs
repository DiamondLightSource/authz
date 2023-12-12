use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::HashMap;

#[derive(Debug, Default, PartialEq, Eq, Serialize)]
pub struct Sessions(HashMap<u32, Vec<(u32, u32)>>);

impl Sessions {
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            SessionRow,
            "
            SELECT
                personId as person_id,
                proposalId as proposal_id,
                visit_number
            FROM Session_has_Person
            JOIN BLSession
            WHERE Session_has_Person.sessionId = BLSession.sessionId
            UNION
            SELECT
                personId as person_id,
                BLSession.proposalId as proposal_id,
                visit_number
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
    proposal_id: u32,
    visit_number: Option<u32>,
}

impl FromIterator<SessionRow> for Sessions {
    fn from_iter<T: IntoIterator<Item = SessionRow>>(iter: T) -> Self {
        let mut sessions = Self::default();
        for session_row in iter {
            sessions.0.entry(session_row.person_id).or_default().push((
                session_row.proposal_id,
                session_row.visit_number.unwrap_or_default(),
            ));
        }
        sessions
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
        fixtures(
            path = "../../tests/fixtures",
            scripts("session_membership", "beamline_sessions")
        )
    )]
    async fn fetch_direct(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = Sessions(HashMap::new());
        expected.0.insert(10, vec![(100, 1), (100, 2)]);
        expected.0.insert(11, vec![(101, 1)]);
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
        expected
            .0
            .insert(10, vec![(100, 1), (100, 2), (100, 3), (101, 1), (101, 2)]);
        expected.0.insert(11, vec![(100, 1), (100, 2), (100, 3)]);
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
        expected
            .0
            .insert(10, vec![(100, 1), (100, 2), (100, 3), (101, 1), (101, 2)]);
        expected
            .0
            .insert(11, vec![(101, 1), (100, 1), (100, 2), (100, 3)]);
        assert_eq!(expected, sessions);
    }
}
