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
            RawProposalRow,
            "
            SELECT
                login AS fed_id,
                proposalNumber AS proposal_number
            FROM (
                    SELECT
                        DISTINCT proposalId,
                        personId
                    FROM
                        ProposalHasPerson
                ) AS UniqueProposalHasPerson
                INNER JOIN Person USING (personId)
                INNER JOIN Proposal USING (proposalId)
            WHERE
                Proposal.externalId IS NOT NULL
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
    fed_id: String,
    /// The proposal number
    proposal_number: u32,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawProposalRow {
    fed_id: Option<String>,
    proposal_number: Option<String>,
}

impl TryFrom<RawProposalRow> for ProposalRow {
    type Error = anyhow::Error;

    fn try_from(value: RawProposalRow) -> Result<Self, Self::Error> {
        Ok(Self {
            fed_id: value.fed_id.ok_or(anyhow::anyhow!("FedId was NULL"))?,
            proposal_number: value
                .proposal_number
                .ok_or(anyhow::anyhow!("Proposal number was NULL"))?
                .parse()?,
        })
    }
}

impl FromIterator<RawProposalRow> for Proposals {
    fn from_iter<T: IntoIterator<Item = RawProposalRow>>(iter: T) -> Self {
        let mut proposals = Self::default();
        for proposal_row in iter {
            if let Ok(proposal_row) = ProposalRow::try_from(proposal_row) {
                proposals
                    .0
                    .entry(proposal_row.fed_id)
                    .or_default()
                    .push(proposal_row.proposal_number)
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
            scripts("proposal_membership", "persons", "proposals")
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let proposals = Proposals::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert("foo".to_string(), BTreeSet::from([10030, 10031, 10032]));
        expected.insert("bar".to_string(), BTreeSet::from([10030]));
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
