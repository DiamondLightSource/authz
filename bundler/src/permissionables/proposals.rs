use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::HashMap;

#[derive(Debug, PartialEq, Eq, Serialize)]
pub struct Proposals(HashMap<u32, Vec<u32>>);

impl Proposals {
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposal_rows = query_as!(
            ProposalRow,
            "
            SELECT DISTINCT
                proposalId as proposal_id,
                personId as person_id
            FROM ProposalHasPerson
            "
        )
        .fetch_all(ispyb_pool)
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

#[cfg(test)]
mod tests {
    use super::Proposals;
    use sqlx::MySqlPool;
    use std::collections::HashMap;

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let proposals = Proposals::fetch(&ispyb_pool).await.unwrap();
        let expected = Proposals(HashMap::new());
        assert_eq!(expected, proposals);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(path = "../../tests/fixtures", scripts("proposal_membership"))
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let proposals = Proposals::fetch(&ispyb_pool).await.unwrap();
        let mut expected = Proposals(HashMap::new());
        expected.0.insert(10, vec![100, 101, 102]);
        expected.0.insert(11, vec![100]);
        assert_eq!(expected, proposals);
    }
}
