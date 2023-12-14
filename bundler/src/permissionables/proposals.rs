use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;

/// A mapping of users to their proposals
#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize)]
pub struct Proposals(BTreeMap<String, Vec<u32>>);

impl Proposals {
    /// Fetches [`Proposals`] from ISPyB
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposal_rows = query_as!(
            ProposalRow,
            "
            SELECT
                proposalId AS proposal_id,
                login AS fed_id
            FROM (
                    SELECT
                        DISTINCT proposalId,
                        personId
                    FROM
                        ProposalHasPerson
                ) AS UniqueProposalHasPerson
                INNER JOIN Person USING (personId)
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(proposal_rows.into_iter().collect())
    }
}

/// A row from ISPyB detailing the proposals a user is associated with
struct ProposalRow {
    /// The FedID of the user
    fed_id: Option<String>,
    /// The proposal number
    proposal_id: u32,
}

impl FromIterator<ProposalRow> for Proposals {
    fn from_iter<T: IntoIterator<Item = ProposalRow>>(iter: T) -> Self {
        let mut proposals = Self::default();
        for proposal_row in iter {
            if let Some(fed_id) = proposal_row.fed_id {
                proposals
                    .0
                    .entry(fed_id)
                    .or_default()
                    .push(proposal_row.proposal_id)
            }
        }
        proposals
    }
}

#[cfg(test)]
mod tests {
    use super::Proposals;
    use sqlx::MySqlPool;
    use std::collections::{BTreeMap, BTreeSet};

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let proposals = Proposals::fetch(&ispyb_pool).await.unwrap();
        let expected = Proposals(BTreeMap::new());
        assert_eq!(expected, proposals);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../tests/fixtures",
            scripts("proposal_membership", "persons")
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let proposals = Proposals::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert("foo".to_string(), BTreeSet::from([30, 31, 32]));
        expected.insert("bar".to_string(), BTreeSet::from([30]));
        assert_eq!(
            expected,
            proposals
                .0
                .into_iter()
                .map(|(k, v)| (k, v.into_iter().collect()))
                .collect()
        );
    }
}
