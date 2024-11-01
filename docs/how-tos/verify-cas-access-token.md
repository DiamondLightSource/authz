# Verify KeyCloak Access Token

## Preface

This guide will explain how to validate a Subject's KeyCloak access token using the KeyCloak JSON Web Key Set (JWKS).

It is recommended you delegate this operation to the [Organisational Policy](../references/organisational-policy.md) following the method described in [Using Organisational Policy](#using-organisational-policy), however the implementation example given in [Implementing Manually](#implementing-manually) can be used if required.

## Using Organisational Policy

When loaded, you can delegate KeyCloak token verification decisions to the [Organisational Policy Bundle](../references/organisational-policy.md) by referencing the `data.diamond.policy.token.claims` variable in your policy and setting the `ISSUER` environment variable to point to the KeyCloak instance - e.g. `https://authn.diamond.ac.uk/realms/master`.

The example below shows how you might write a system package which allows the action if `input.action` is "do_thing" and the `input.token` is for the subject "bob".

!!! example

    ```rego title="system.rego"
    package system

    import data.diamond.policy.token
    import rego.v1

    # METADATA
    # description: Allow bob to do a thing
    # entrypoint: true
    main := {"allow": allow}

    default allow := false

    # Allow bob to do the thing
    allow if {
        input.action == "do_thing"
        token.claims.sub == "bob"
    }
    ```


## Implementing Manually

User `claim`s are derived from the token, with verification performed against the JSON Web Key Set, with the Key Set cycled periodically.

```rego
{%
    include "../../policy/diamond/policy/token/token.rego"
%}
```
