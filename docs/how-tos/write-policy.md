# Write Policy

## Preface

This guide will explain how to write an OPA policy in the Rego language. It is strongly recommended that you implement [Policy Lintin and Testing](lint-test-policy.md).

!!! tip

    See also:
    
    - [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
    - [OPA Policy Reference](https://www.openpolicyagent.org/docs/latest/policy-reference/)
    - [OPA Playground](https://play.openpolicyagent.org/).

## Evaluate Policy

OPA allows us to evaluate policy via the CLI using [`opa eval`](https://www.openpolicyagent.org/docs/latest/cli/#opa-eval). The policy bundle we are creating can be passed in using the `--bundle` option, whilst the path of the policy we want to evaluate is given as the first argument. If inputs are required, a file containing them can be passed in using the `--input` option. As with all commands, the `--v1-compatible` flag is recommended.

!!! example

    ```shell
    opa eval --v1-compatible --bundle policy/ --input my_input.json 'system.main'
    ```

## Packages and Imports

OPA policies consist of multiple packages, each of which may be spread over multiple files. To specify the package name we specify `package <PACKAGE_NAME>` at the beginning of the file. It is likely you will want to name your main package `system`, as explained further in the [Entrypoints section](#entrypoints-and-defaults).

Other packages may be referenced by your current package via an import, these take the form `import data.other_package` and make variables and functions accesible in the current scope like `other_package.some_variable`.

The `rego.v1` import introduces various v1 compatible symantics, it is strongly recommended as it guarentees forward compatibility.

!!! example

    ```rego title="system.rego"
    package system

    import rego.v1
    ```

!!! note

    The `input` and `data` namespaces are imported by default and provide access to request inputs and pre-loaded data respectively.

## Entrypoints and Defaults

Policies should have at least one entrypoint, a root decision of whether a request is allowed. This should default to `false` - requests are disallowed unless they meet criteria.

OPA uses the `data.system.main` rule as the default entrypoint. Hence this is what is called when a `POST` request is made to the root path (`/`) as described in the [OPA REST Query API Docs](https://www.openpolicyagent.org/docs/latest/rest-api/#query-api).

The `default` keyword sets the value of a variable if and only if it is not defined by any other rules. To ensure our policy fails in a safe manner we define the default `allow` value to be `false` and explicity set it to `true` where permissable.

!!! example

    ```rego
    package system

    import rego.v1

    # METADATA
    # entrypoint: true
    main := {"allow": allow}

    default allow := false
    ```

## Useful Patterns

### Equality and Ordering

The equality of variables can be checked with the `==` operator.

The inequality of variables can be checked with the `!=` operator.

The ordering of variables can be checked with the `>` and `<` operators for greater than and lesser than respectively.

### AND

All expressions inside braces (`{ }`) must evaluate to a truthy value in order for the span to evaluate to true, hence acting as a logical `AND`.

!!! example

    ```rego
    a_and_b if {
      input.a == 42
      input.b != "foo"
    }
    ```

### OR

Variables which are defined multiple times will be executed until a truthy value is encountered, hence acting as a locical `OR`.

!!! example

    ```rego
    a_or_b if {
      input.a = 42
    }

    a_or_b if {
      input.b != "foo"
    }
    ```