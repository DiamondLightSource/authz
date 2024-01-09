use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of users to their proposals
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct SubjectProposals(BTreeMap<String, Vec<u32>>);

impl SubjectProposals {
    /// Fetches [`Proposals`] from ISPyB
    #[instrument(name = "fetch_proposals")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let proposal_rows = query_as!(
            RawProposalRow,
            "
            SELECT
                login AS subject,
                proposalNumber AS proposal_number
            FROM ProposalHasPerson
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

/// A row from ISPyB detailing the proposals a subject is associated with
struct ProposalRow {
    /// The unique identifier of the subject
    subject: String,
    /// The proposal number
    proposal_number: u32,
}

#[allow(clippy::missing_docs_in_private_items)]
struct RawProposalRow {
    subject: Option<String>,
    proposal_number: Option<String>,
}

impl TryFrom<RawProposalRow> for ProposalRow {
    type Error = anyhow::Error;

    fn try_from(value: RawProposalRow) -> Result<Self, Self::Error> {
        Ok(Self {
            subject: value.subject.ok_or(anyhow::anyhow!("FedId was NULL"))?,
            proposal_number: value
                .proposal_number
                .ok_or(anyhow::anyhow!("Proposal number was NULL"))?
                .parse()?,
        })
    }
}

impl FromIterator<RawProposalRow> for SubjectProposals {
    fn from_iter<T: IntoIterator<Item = RawProposalRow>>(iter: T) -> Self {
        let mut proposals = Self::default();
        for proposal_row in iter {
            if let Ok(proposal_row) = ProposalRow::try_from(proposal_row) {
                proposals
                    .entry(proposal_row.subject)
                    .or_default()
                    .push(proposal_row.proposal_number)
            }
        }
        proposals
    }
}

#[cfg(test)]
mod tests {
    use super::SubjectProposals;
    use sqlx::MySqlPool;
    use std::collections::{BTreeMap, BTreeSet};

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let proposals = SubjectProposals::fetch(&ispyb_pool).await.unwrap();
        let expected = SubjectProposals(BTreeMap::new());
        assert_eq!(expected, proposals);
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../../tests/fixtures",
            scripts("proposal_membership", "persons", "proposals")
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let proposals = SubjectProposals::fetch(&ispyb_pool).await.unwrap();
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
