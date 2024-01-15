# Writing OPA policy

## Preface

This guide will explain how to write, test and build rego language policy into a bundle which can be used as an entrypoint to your AuthZ decisions, the "Application Policy" referred to in the preface of the [configuring OPA how-to](configure-opa.md).

See also [the OPA documentation on Rego](https://www.openpolicyagent.org/docs/latest/policy-language/), [the basics of Rego](https://www.openpolicyagent.org/docs/latest/policy-language/#the-basics) and the [opa playground](https://play.openpolicyagent.org/).

## Writing Policy

A possible pattern for writing policy is to build it from the same repository as your application, in a `policy` directory. This keeps your policy close to the relevant code for reference, and versions the two together easily.

Policy must be written in packages, which may inherit from other packages (subpackages) and may be spread over multiple files. The following code blocks build up an example `policy/policy.rego`.

It is highly recommended to `import rego.v1` keywords, and the provided github action linting enforces use of these keywords.

Your application policy should have at least one entrypoint, a root decision of whether a request is allowed. For testing this may default to `true`, but for live deployments this should default to `false`: requests are disallowed unless they meet criteria.

The `default` keyword defines `allow` if and only if `allow` is not defined by any other rules. `opa` parses all rules defined from the called `entrypoint` and tries to build a complete document from them: in this way, defining a rule multiple times can be understand as an `or`, while adding multiple clauses to a rule requires that all clauses are defined for the rule to be defined: i.e., an `and`

```rego
package my.service.policy

import rego.v1

# METADATA
# description: 'The entry point to my bundle: `true` if any definition of `allow` is true'
# entrypoint: true
default allow := false

# METADATA
# description: Provides a value for allow if some_rule can be defined as a constant value
allow if {  
  some_rule
}

# METADATA
# description: Provides a value for allow if some_other_rule can be defined as a constant value AND some_third_thing can be defined as a constant value
allow if {
  some_other_rule
  some_third_thing
}
```

The request that the rules are being evaluated against can be access from the reserved keyword `input`, while any other policy or bundled data can be access under the reserved keyword `data`: for example, policy written in the `diamond.policy` package is accessible under `data.diamond.policy`. The structure of `input` will vary depending on how OPA is called, and an example can typically be found in the documentation.

## Testing Policy

- Tests for policy should be defined in `foo_test.rego` if they are testing functionality from module `foo.rego`.
- Tests should be in a package `bar_test` if they are testing policy in package `bar` (this is a requirement for the `regal` linter)
- Test cases within `foo_test.rego` must be named `test_*`.

The following test file mocks the `some_rule` which would have been defined in the previous example.

For local testing and building of policy, use [the opa executable](https://www.openpolicyagent.org/docs/latest/#1-download-opa) and the [opa test](https://www.openpolicyagent.org/docs/latest/cli/#opa-test) command.

```rego
package my.service.policy_test

import rego.v1
import my.service.policy #  implied "as policy"

user_on_proposal if {
	input.request_path[0] is 0
}

test_default_disallowed if {
	allow with input as {} 
  with policy.some_rule as user_on_proposal
}

test_allow_user_on_proposal if {
	allow with input as {"request_path": [0]} 
  with policy.some_rule as user_on_proposal
}
```

## Building OPA policy

To build your OPA policy into an OCI bundle to be served from the github container registry, rather than mounting the .rego source directly requires the addition of a `.manifest` file to your policy root directory.

Below is a minimal `.manifest`, defining the package root below which it will attempt to override the namespace. It is recommended to use a package structure which will not collide with mounted data or other policy, such as `<name of service>/policy` for your policy.

```json
{
    "roots": ["my/service/policy"]
}
```

#### Note: Some IDE git integrations do not commit hidden files like `.manifest` automatically, and you may need to add it to a commit manually.

!!! example "Github action for testing/linting policy"

    {%
        include-markdown "../references/building-policy.md"
        heading-offset=1
    %}

- Runs on every pull_request or push to a branch (but only once)
- Lints all policy, runs all test cases
- Checks that policy can be built into a valid bundled)

!!! example "Github action for building policy into OCI bundle and pushing to GHCR"

    {%
        include-markdown "../references/publishing-policy.md"
        heading-offset=1
    %}

- Runs on every pull_request or push to a branch (but only once)
- Builds all policy in `policy/` directory, except that in files matching `*_test.rego` (i.e., excluding any tests) into a bundle
- If the push to a branch had a tag created for the repository, pushes bundle as an OCI image that is release on the Github Container Registry [for consumption by a configured instance](configure-opa.md)
