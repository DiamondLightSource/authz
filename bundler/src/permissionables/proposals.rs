use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of proposals to their various attributes
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Proposals(BTreeMap<u32, Proposal>);

impl Proposals {
    /// Fetches [`Proposals`] from ISPyB
    #[instrument(name = "fetch_proposals")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposal_rows = query_as!(
            RawProposalRow,
            "
            SELECT
                proposalNumber as proposal_number,
                visit_number,
                sessionId as session_id
            FROM
                BLSession
                JOIN Proposal USING (proposalId)
            WHERE
                Proposal.externalId IS NOT NULL
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(proposal_rows.into_iter().collect())
    }
}

/// The various attributes of a proposal
#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Proposal {
    /// The sessions which took place within the proposal
    sessions: BTreeMap<u32, u32>,
}

/// A row from ISPyB detailing the sessions in a proposal
struct ProposalRow {
    /// The proposal number
    proposal_number: u32,
    /// The number of the visit on the proposal
    visit_number: u32,
    /// An opaque identifier of the session
    session_id: u32,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawProposalRow {
    proposal_number: Option<String>,
    visit_number: Option<u32>,
    session_id: u32,
}

impl TryFrom<RawProposalRow> for ProposalRow {
    type Error = anyhow::Error;

    fn try_from(value: RawProposalRow) -> Result<Self, Self::Error> {
        Ok(Self {
            proposal_number: value
                .proposal_number
                .ok_or(anyhow::anyhow!("Proposal Number was NULL"))?
                .parse()?,
            visit_number: value.visit_number.unwrap_or_default(),
            session_id: value.session_id,
        })
    }
}

impl FromIterator<RawProposalRow> for Proposals {
    fn from_iter<T: IntoIterator<Item = RawProposalRow>>(iter: T) -> Self {
        let mut proposals = Self::default();
        for proposal_row in iter {
            if let Ok(proposal_row) = ProposalRow::try_from(proposal_row) {
                proposals
                    .entry(proposal_row.proposal_number)
                    .or_default()
                    .sessions
                    .insert(proposal_row.visit_number, proposal_row.session_id);
            }
        }
        proposals
    }
}

#[cfg(test)]
mod tests {
    use super::{Proposal, Proposals};
    use sqlx::MySqlPool;
    use std::collections::BTreeMap;

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let proposals = Proposals::fetch(&ispyb_pool).await.unwrap();
        let expected = Proposals(BTreeMap::new());
        assert_eq!(expected, proposals);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            "../../tests/fixtures/beamline_sessions.sql",
            "../../tests/fixtures/proposals.sql"
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let beamlines = Proposals::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            10030,
            Proposal {
                sessions: BTreeMap::from([(10, 40), (11, 41), (12, 42)]),
            },
        );
        expected.insert(
            10031,
            Proposal {
                sessions: BTreeMap::from([(10, 43), (11, 44)]),
            },
        );
        assert_eq!(expected, beamlines.0);
    }
}
