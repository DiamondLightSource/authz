use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::HashMap;

#[derive(Debug, Serialize)]
pub struct Sessions(HashMap<u32, Vec<u32>>);

impl Sessions {
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            SessionRow,
            "
            SELECT
                personId as person_id,
                sessionId as session_id
            FROM
                Session_has_Person
            UNION
            SELECT
                BLSession.proposalId,
                sessionId
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
