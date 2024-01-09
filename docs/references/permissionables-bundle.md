# Permissionables Bundle

The permissioanbles bundle supplied by the Bundler contains three mappings; User Permissions, User Proposals, and User Sessions.

## User Permissions

User permissions are exposed at `diamond.data.users.permissions`. They are provided as a mapping where the key is the `FedID` of the user with values corresponding to a list of `permission type`s.

## User Proposals

User proposals are exposed at `diamond.data.users.proposals`. They are provided as a mapping where the key is the `FedID` of the user with values corresponding to a list of `proposal number`s.

## User Sessions 

User visits are exposed at `diamond.data.users.sessions`. They are provided as a mapping where the key is the `FedID` of the user with values corresponding to a list of tuples of `proposal number` and `visit number`.
