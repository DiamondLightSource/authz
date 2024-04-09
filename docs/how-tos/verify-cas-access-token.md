# Verify CAS Access Token

## Preface

This guide will explain how to validate a Subject's CAS access token using the CAS User Info endpoint.

It is recommended you delegate this operation to the [Organisational Policy](../references/organisational-policy.md) following the method described in [Using Organisational Policy](#using-organisational-policy), however the implementation example given in [Implementing Manually](#implementing-manually) can be used if required.

## Using Organisational Policy

When loaded, you can delegate CAS token verification decisions to the [Organisational Policy Bundle](../references/organisational-policy.md) by referencing the `data.diamond.policy.token.subject` variable in your policy and setting the `USERINFO_ENDPOINT` environment variable to point to the CAS User Info endpoint - e.g. `https://auth.diamond.ac.uk/cas/oidc/oidcProfile`.

The example below shows how you might write a system package which allows the action if `input.action` is "do_thing" and the `input.token` is for the subject "bob".

!!! example

    **`system.rego`**:

    ```rego
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
        subject := token.verify(input.token)
        subject == "bob"
    }
    ```


## Implementing Manually

The `data.diamond.policy.token.subject` variable is implemented as an HTTP `GET` request to the CAS User Info Endpoint, provided by the `USERINFO_ENDPOINT` environment variable, as below:

```rego
{%
    include "../../org-policy/token.rego"
%}
```
