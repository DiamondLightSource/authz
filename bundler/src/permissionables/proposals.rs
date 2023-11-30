use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::HashMap;

#[derive(Debug, Serialize)]
pub struct Proposals(HashMap<u32, Vec<u32>>);

impl Proposals {
    pub async fn fetch(pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposal_rows = query_as!(
            ProposalRow,
            "
            SELECT
                proposalId as proposal_id,
                personId as person_id
            FROM ProposalHasPerson
            "
        )
        .fetch_all(pool)
        .await?;

        Ok(proposal_rows.into_iter().collect())
    }
}

struct ProposalRow {
    person_id: u32,
    proposal_id: u32,
}

impl FromIterator<ProposalRow> for Proposals {
    fn from_iter<T: IntoIterator<Item = ProposalRow>>(iter: T) -> Self {
        let mut proposals = HashMap::<u32, Vec<u32>>::default();

        for proposal_row in iter {
            proposals
                .entry(proposal_row.person_id)
                .or_default()
                .push(proposal_row.proposal_id)
        }

        Self(proposals)
    }
}
