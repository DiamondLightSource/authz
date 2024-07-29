use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of beamlines to their various attributes
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Beamlines(BTreeMap<String, Beamline>);

impl Beamlines {
    /// Fetches [`Beamlines`] from ISPyB
    #[instrument(name = "fetch_beamlines")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let session_rows = query_as!(
            RawBeamlineRow,
            "
            SELECT
                beamLineName as beamline,
                sessionId as session_id
            FROM
                BLSession
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(session_rows.into_iter().collect())
    }
}

/// The various attributes of a beamline
#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Beamline {
    /// The sessions which occured on this beamline
    sessions: Vec<u32>,
}

/// A row from ISPyB detailing the sessions on a beamline
struct BeamlineRow {
    /// The beamline name
    beamline: String,
    /// An opaque identifier of the session
    session_id: u32,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawBeamlineRow {
    beamline: Option<String>,
    session_id: u32,
}

impl TryFrom<RawBeamlineRow> for BeamlineRow {
    type Error = anyhow::Error;

    fn try_from(value: RawBeamlineRow) -> Result<Self, Self::Error> {
        Ok(Self {
            beamline: value
                .beamline
                .ok_or(anyhow::anyhow!("Beamline Name was NULL"))?
                .parse()?,
            session_id: value.session_id,
        })
    }
}

impl FromIterator<RawBeamlineRow> for Beamlines {
    fn from_iter<T: IntoIterator<Item = RawBeamlineRow>>(iter: T) -> Self {
        let mut beamlines = Self::default();
        for beamline_row in iter {
            if let Ok(beamline) = BeamlineRow::try_from(beamline_row) {
                beamlines
                    .entry(beamline.beamline)
                    .or_default()
                    .sessions
                    .push(beamline.session_id)
            }
        }
        beamlines
    }
}

#[cfg(test)]
mod tests {
    use super::{Beamline, Beamlines};
    use sqlx::MySqlPool;
    use std::collections::BTreeMap;

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let beamlines = Beamlines::fetch(&ispyb_pool).await.unwrap();
        let expected = Beamlines(BTreeMap::new());
        assert_eq!(expected, beamlines);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures("../../tests/fixtures/beamline_sessions.sql")
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let beamlines = Beamlines::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert("i12".to_string(), Beamline { sessions: vec![40] });
        expected.insert(
            "i22".to_string(),
            Beamline {
                sessions: vec![41, 44],
            },
        );
        expected.insert("b13".to_string(), Beamline { sessions: vec![42] });
        expected.insert("p99".to_string(), Beamline { sessions: vec![43] });
        assert_eq!(expected, beamlines.0);
    }
}
