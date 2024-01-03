# Permissionables Bundle

The permissioanbles bundle supplied by the Bundler contains four mappings; Subject Attributes, Session Attributes, Proposal Attributes, and Beamline Attributes.

## Subject Attributes

Subject attributes are exposed at `diamond.data.subjects`. They are provided as a mapping where the key is the IdP `subject` identifier of the Subject with value objects containing:

- A list of `title`s of the Permissions the Subject has been granted
- A list of `number`s of the Proposals the Subject is associated with
- A list of `number`s of the Sessions the Subject is associated with

An example struct is shown below:

```json
{
    "permissions": ["i22_admin"],
    "proposals": [12345],
    "sessions": [54321, 65432]
}
```

## Session Attributes

Session attributes are exposed at `diamond.data.sessions`. They are provided as a mapping where the key is an opaque `number` of the Session with value objects containing:

- The `number` of the associated Proposal
- The `number` of the associated Visit within the Proposal
- The `name` of the associated Beamline

An example struct is shown below:

```json
{
    "proposal_number": 12345,
    "visit_number": 4,
    "beamline": "i22"
}
```

## Proposal Attributes

Proposal attributes are exposed at `diamond.data.proposals`. They are provided as a mapping where the key is `number` of the Proposal with value objects containing:

- A list of `number`s of the Sessions which occurred under this proposal

An example struct is shown below:

```json
{
    "sessions": {
        "1": 54321,
        "2": 65432
    }
}
```
## Beamline Attributes

Beamline attributes are exposed at `diamond.data.beamlines`. They are provided as a mapping where the key is the `name` of the Subject with value objects containing:

- A list of `number`s of the Sessions which have occurred on the Beamline

An example struct is shown below:

```json
{
    "sessions": [54321, 65432]
}
```
