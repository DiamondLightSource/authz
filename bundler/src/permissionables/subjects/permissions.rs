use derive_more::{Deref, DerefMut};
use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of subjects to their permissions via roles
#[derive(Debug, Default, Deref, DerefMut, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct SubjectPermissions(BTreeMap<String, Vec<String>>);

impl SubjectPermissions {
    /// Fetches [`SubjectAttributes`] from ISPyB
    #[instrument(name = "fetch_subject_permissions")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let permisions_rows = query_as!(
            PermissionRow,
            "
            SELECT
                login as subject,
                type as permission
            FROM Person
                JOIN UserGroup_has_Person ON Person.personId = UserGroup_has_Person.personId
                JOIN UserGroup USING (userGroupId)
                JOIN UserGroup_has_Permission USING (userGroupId)
                JOIN Permission USING (permissionId)
            "
        )
        .fetch_all(ispyb_pool)
        .await?;

        Ok(permisions_rows.into_iter().collect())
    }
}

/// A row from ISPyB detailing the attributes a subject has been given
struct PermissionRow {
    /// The unique identifier of the subject
    subject: Option<String>,
    /// The attribute the subject has been given
    permission: String,
}

impl FromIterator<PermissionRow> for SubjectPermissions {
    fn from_iter<T: IntoIterator<Item = PermissionRow>>(iter: T) -> Self {
        let mut permissions = Self::default();
        for permission_row in iter {
            if let Some(fed_id) = permission_row.subject {
                permissions
                    .entry(fed_id)
                    .or_default()
                    .push(permission_row.permission)
            }
        }
        permissions
    }
}

#[cfg(test)]
mod tests {
    use super::SubjectPermissions;
    use sqlx::MySqlPool;
    use std::collections::{BTreeMap, BTreeSet};

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let permissions = SubjectPermissions::fetch(&ispyb_pool).await.unwrap();
        let expected = SubjectPermissions::default();
        assert_eq!(expected, permissions)
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../../tests/fixtures",
            scripts(
                "persons",
                "user_groups",
                "user_group_membership",
                "permissions",
                "group_permissions"
            )
        )
    )]
    async fn fetch_some(ispyb_pool: MySqlPool) {
        let permissions = SubjectPermissions::fetch(&ispyb_pool).await.unwrap();
        let mut expected = BTreeMap::new();
        expected.insert(
            "foo".to_string(),
            BTreeSet::from([
                "read_data".to_string(),
                "write_data".to_string(),
                "read_proc".to_string(),
            ]),
        );
        expected.insert(
            "bar".to_string(),
            BTreeSet::from(["read_data".to_string(), "write_data".to_string()]),
        );
        assert_eq!(
            expected,
            permissions
                .0
                .into_iter()
                .map(|(k, v)| (k, v.into_iter().collect()))
                .collect()
        )
    }
}
