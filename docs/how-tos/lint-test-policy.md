# Lint & Test Policy

## Preface

This guide will explain how to lint and test an OPA policy. Linting will be performed using [Regal](https://docs.styra.com/regal) whilst testing will utilize [`opa test`](https://www.openpolicyagent.org/docs/latest/cli/#opa-test).

!!! tip

    See also:
    
    - [OPA Policy Testing](https://www.openpolicyagent.org/docs/latest/policy-testing/)
    - [Regal Linter](https://docs.styra.com/regal)

## Linting

### Running Lints

The Regal linter is used to evaluate a large [suite of rules](https://docs.styra.com/regal/category/rules) which are designed to detect likely bugs and prevent non-idiomatic or non-performant code. Regal linting can be run using [`regal lint`](https://docs.styra.com/regal/category/rules). The policy bundle we are linting should be passed in as the first agument.

!!! example

    ```shell
    regal lint policy/
    ```

## Testing

### Running Tests

OPA tests can be evaluated using the [`opa test`](https://www.openpolicyagent.org/docs/latest/cli/#opa-test). The policy bundle we are testing should be passed in as the first argument. As with all commands, the `--v1-compatible` flag is recommended.

!!! example

    ```shell
    opa test --v1-compatible policy/
    ```

### Packages and Imports

OPA test packages should be named equivilently to their policy counterpart with the addition of a `_test` suffix. Similarly, the file name should match the file name of the package with a `_test` suffix.

!!! example

    **`system.rego`**:
    ```rego
    package system

    import rego.v1

    # METADATA
    # entrypoint: true
    main := {"allow": allow}

    default allow := false
    ```

    **`system_test.rego`**:
    ```rego
    package system_test

    import data.system
    import rego.v1
    ```

!!! note

    The `input` and `data` namespaces are imported by default and provide access to request inputs and pre-loaded data respectively.

### Writing Tests

Test cases should begin with `test_` with a name which describes the expected behaviour and the conditions under which it should occur. Typically test cases follow an [AND pattern](write-policy.md#and), ensuring the fail if any one of the expressions within fails. Where an expression is expected to fail, you should prefix it with `not`.

!!! note

    Whilst it is useful to test that rules pass where expected, it is more important to check that they fail safely and correctly deny access in all instances where it should not be granted.

!!! example

    **`system.rego`**:
    ```rego
    package system

    import rego.v1

    # METADATA
    # entrypoint: true
    main := {"allow": allow}

    default allow := false

    allow if {
        input.action == "get_foo"
        "read_foo" in data.subjects[input.subject].permissions
    }
    ```

    **`system_test.rego`**:
    ```rego
    package system_test

    import data.system
    import rego.v1

    test_member_allowed if {
        system.main.allow with input as {"action": "get_foo", "subject": "bob"}
            with data.subjects as {"bob": {"permissions": ["read_foo]}}
    }

    test_unknown_action_denied if {
        not system.main.allow with input.action as "write_bar"
    }

    test_non_member_denied if {
        not system.main.allow with input as {"action": "get_foo", "subject": "bob"}
            with data.subjects as {"bob": {"permissions": []}}
    }
    ```

## Continious Integration

It is strongly recommeneded you implement automated linting and testing as part of your Continious Integration (CI) pipeline, an example for doing this in GitHub Actions is shown below.

!!! example "GitHub Actions lint and test workflow"

    ```yaml
    {%
          include "../../.github/workflows/policy-code.yml"
    %}
    ```