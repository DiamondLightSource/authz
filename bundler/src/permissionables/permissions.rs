use schemars::JsonSchema;
use serde::Serialize;
use sqlx::{query_as, MySqlPool};
use std::collections::BTreeMap;
use tracing::instrument;

/// A mapping of users to their permissions via groups
#[derive(Debug, Default, PartialEq, Eq, Hash, Serialize, JsonSchema)]
pub struct Permissions(BTreeMap<String, Vec<String>>);

impl Permissions {
    /// Fetches [`Permissions`] from ISPyB
    #[instrument(name = "fetch_permissions")]
    pub async fn fetch(ispyb_pool: &MySqlPool) -> Result<Self, sqlx::Error> {
        let permisions_rows = query_as!(
            PermissionRow,
            "
            SELECT
                login as fed_id,
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

/// A row from ISPyB detailing the permissions a user has been given
struct PermissionRow {
    /// The FedID of the user
    fed_id: Option<String>,
    /// The permission the user has been given
    permission: String,
}

impl FromIterator<PermissionRow> for Permissions {
    fn from_iter<T: IntoIterator<Item = PermissionRow>>(iter: T) -> Self {
        let mut permissions = Self::default();
        for permission_row in iter {
            if let Some(fed_id) = permission_row.fed_id {
                permissions
                    .0
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
    use super::Permissions;
    use sqlx::MySqlPool;
    use std::collections::{BTreeMap, BTreeSet};

    #[sqlx::test(migrations = "tests/migrations")]
    async fn fetch_empty(ispyb_pool: MySqlPool) {
        let permissions = Permissions::fetch(&ispyb_pool).await.unwrap();
        let expected = Permissions::default();
        assert_eq!(expected, permissions)
    }

    #[sqlx::test(
        migrations = "tests/migrations",
        fixtures(
            path = "../../tests/fixtures",
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
        let permissions = Permissions::fetch(&ispyb_pool).await.unwrap();
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
