# Organisational Policy

A baseline organisational policy is made available for use in your OPA instances, it aims to implement agreed upon Authorization practices for common queries, these include:

- [Proposal Access](#proposal-access) via `data.diamond.policy.proposal.access_proposal`
- [Session Access](#session-access) via `data.diamond.policy.session.access_session`

Additioanlly, [Token Verification](#token-verification) is implemented in the `data.diamond.policy.token.verify` function.

## Proposal Access

Queried via `data.diamond.policy.proposal.access_proposal`

The proposal access function allows you to determine if a given Subject is permitted to access a given Proposal. Access is permitted if any of the following conditions are met:

- The Subject has the `super_admin` attribute
- The Subject is a member of the Proposal

To make a decision the following inputs must be supplied:

- `subject`: The Subject making the request request. The Subject identifier can be attained via [Token Verification](#token-verification).
- `proposal_number`: The proposal number, as an unsigned integer

!!! note

    Subject attributes and Proposal membership are supplied by the [Diamond Data Bundle](../references/diamond-data-bundle.md).

## Session Access

Queried via `data.diamond.policy.session.access_session`

The session access function allows you to determine if a given Subject is permitted to access a given beamline Session. Access is permitted if any of the following conditions are met:

- The Subject has the `super_admin` attribute
- The Subject is a member of the Proposal which this Session belongs to
- The Subject is a member of the Session
- The Subject has a beamline admin attribute (e.g. `b07_admin`) which corresponds to the beamline on which the Session took place
- The Subject has a science group admin attribute (e.g. `mx_admin`) which corresponds to the science group of the beamline on which the Session took place

To make a decision the following inputs must be supplied:

- `subject`: The Subject making the request request. The Subject identifier can be attained via [Token Verification](#token-verification).
- `proposal_number`: The proposal number, as an unsigned integer
- `visit_number`: The visit number, as an unsigned integer

!!! note

    Subject attributes, Session membership, and Proposal membership are supplied by the [Diamond Data Bundle](../references/diamond-data-bundle.md).

## Token Verification

Queried via `diamond.policy.token.verify`

The token verification function allows you to check that an access token is valid, it returns the Subject who owns the access token. This is performed by querying the CAS User Info Endpoint, and is compatible with:

- `auth.diamond.ac.uk`
- `authbeta.diamond.ac.uk`
- `authalpha.diamond.ac.uk`

The CAS User Info Endpoint instance is supplied via the `USERINFO_ENDPOINT` environment variable.

!!! warning

    The token verification function performs an HTTP request, thus it is not suitable for usage in a hot loop
