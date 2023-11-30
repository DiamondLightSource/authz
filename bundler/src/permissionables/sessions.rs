use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::HashMap;

#[derive(Debug, Serialize)]
pub struct Sessions(HashMap<u32, Vec<u32>>);

impl Sessions {
    pub async fn fetch(pool: &MySqlPool) -> Result<Self, sqlx::Error> {
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
            FROM ProposalHasPerson
                CROSS JOIN BLSession
            WHERE
                ProposalHasPerson.proposalId = BLSession.proposalId
            "
        )
        .fetch_all(pool)
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
