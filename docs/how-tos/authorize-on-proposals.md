# Authorize on Proposals

## Preface

This guide will explain how to authorize a Subject's access request based on the Proposal which they intend to access.

This access rule is implemented as part of the [Organisational Policy](../references/organisational-policy.md). As such, you should include this and the [Diamond Data Bundle](../references/diamond-data-bundle.md) when you [configure OPA](configure-opa.md) or as described in the guide for your [helm](deploy-with-helm.md) or [local docker-compose](deploy-docker-compose.md) deployment.

## Delegate Policy Decisions

When loaded, you can delegate policy decisions of your system entrypoint to the [Organisational Policy](../references/organisational-policy.md) by calling the `data.diamond.policy.proposal.access_proposal` function in your policy with the subject identifier and proposal number.

The example below shows how you might write a system package which extracts the subject from the access token and checks they are allowed to view the requested proposal using `data.diamond.policy.proposal.access_proposal`.

!!! example

    ```rego title="system.rego"
    package system

    import data.diamond.policy.proposal
    import data.diamond.policy.token
    import rego.v1

    # METADATA
    # description: Allow if subject is permitted to perform requested action
    # entrypoint: true
    main := {"allow": allow}

    default allow := false

    # Allow if subject is permitted to access the proposal
    allow if {
        subject := token.verify(input.token)
        proposal.access_proposal(subject, input.proposal)
    }
    ```

The system policy decision can be queried at `http://opa:8181` with use of the [OPA REST Query API](https://www.openpolicyagent.org/docs/latest/rest-api/#query-api).

!!! example

    `POST` `http://opa:8181` with:

    ```json
    {
      "input": {
        "token": "<YOUR_ACCESS_TOKEN>",
        "proposal": 12345
      }
    }
    ```

    Response:

    ```json
    {
      "result": true
    }
    ```
