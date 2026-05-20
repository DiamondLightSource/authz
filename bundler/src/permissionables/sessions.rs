use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{MySqlPool, query_as};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of sessions to their various attributes
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Sessions(BTreeMap<u32, Session>);

impl Sessions {
    /// Fetches [`Sessions`] from ISPyB
    #[instrument(name = "fetch_sessions")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            RawSessionRow,
            "
            SELECT
                sessionId as session_id,
                proposalNumber as proposal_number,
                visit_number,
                beamLineName as beamline,
                UNIX_TIMESTAMP(BLSession.startDate) as start_time,
                UNIX_TIMESTAMP(BLSession.endDate) as end_time
            FROM
                BLSession
                JOIN Proposal USING (proposalId)
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(session_rows.into_iter().collect())
    }
}

/// The various attributes of a session
#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Session {
    /// The number of the proposal this session belongs to
    proposal_number: u32,
    /// The number of the visit within the proposal this session belongs to
    visit_number: u32,
    /// The beamline the session took place on
    beamline: String,
    /// The session start time expressed as a Unix timestamp in seconds.
    start_time: i64,
    /// The session end time expressed as a Unix timestamp in seconds.
    end_time: i64,
}

/// A row from ISPyB detailing the beamline a session took place on
struct SessionRow {
    /// An opaque identifier of the session
    session_id: u32,
    /// The proposal number of the visit
    proposal_number: u32,
    /// The number of the visit within the proposal
    visit_number: u32,
    /// The beamline the session took place on
    beamline: String,
    /// The session start time expressed as a Unix timestamp in seconds.
    start_time: i64,
    /// The session end time expressed as a Unix timestamp in seconds.
    end_time: i64,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawSessionRow {
    session_id: u32,
    proposal_number: Option<String>,
    visit_number: Option<u32>,
    beamline: Option<String>,
    start_time: Option<i64>,
    end_time: Option<i64>,
}

impl TryFrom<RawSessionRow> for SessionRow {
    type Error = anyhow::Error;

    fn try_from(value: RawSessionRow) -> Result<Self, Self::Error> {
        Ok(Self {
            session_id: value.session_id,
            proposal_number: value
                .proposal_number
                .ok_or(anyhow::anyhow!("Proposal number was NULL"))?
                .parse()?,
            visit_number: value.visit_number.unwrap_or_default(),
            beamline: value.beamline.ok_or(anyhow::anyhow!("Beamline was NULL"))?,
            start_time: value.start_time.unwrap_or_default(),
            end_time: value.end_time.unwrap_or_default(),
        })
    }
}

impl FromIterator<RawSessionRow> for Sessions {
    fn from_iter<T: IntoIterator<Item = RawSessionRow>>(iter: T) -> Self {
        let mut sessions = Self::default();
        for session_row in iter {
            if let Ok(session_row) = SessionRow::try_from(session_row) {
                sessions.insert(
                    session_row.session_id,
                    Session {
                        proposal_number: session_row.proposal_number,
                        visit_number: session_row.visit_number,
                        beamline: session_row.beamline,
                        start_time: session_row.start_time,
                        end_time: session_row.end_time,
                    },
                );
            }
        }
        sessions
    }
}

#[cfg(test)]
mod tests {
    use super::{Session, Sessions};
    use sqlx::MySqlPool;
    use std::collections::BTreeMap;

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let expected = Sessions(BTreeMap::new());
        assert_eq!(expected, sessions);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            "../../tests/fixtures/beamline_sessions.sql",
            "../../tests/fixtures/proposals.sql"
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let sessions = Sessions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            40,
            Session {
                proposal_number: 10030,
                visit_number: 10,
                beamline: "i12".to_string(),
                start_time: 1778662800,
                end_time: 1778691600,
            },
        );
        expected.insert(
            41,
            Session {
                proposal_number: 10030,
                visit_number: 11,
                beamline: "i22".to_string(),
                start_time: 1778576400,
                end_time: 1778605200,
            },
        );
        expected.insert(
            42,
            Session {
                proposal_number: 10030,
                visit_number: 12,
                beamline: "b13".to_string(),
                start_time: 1778490000,
                end_time: 1778518800,
            },
        );
        expected.insert(
            43,
            Session {
                proposal_number: 10031,
                visit_number: 10,
                beamline: "p99".to_string(),
                start_time: 1778403600,
                end_time: 1778432400,
            },
        );
        expected.insert(
            44,
            Session {
                proposal_number: 10031,
                visit_number: 11,
                beamline: "i22".to_string(),
                start_time: 1778317200,
                end_time: 1778346000,
            },
        );
        assert_eq!(expected, sessions.0);
    }
}
