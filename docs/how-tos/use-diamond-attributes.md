# Write OPA policy against Diamond Attributes

## Preface

To assist in writing policy, some basic decisions have been extracted to a `diamond.policy` package, from `org-policy` in this repository. This policy handles parsing authentication tokens into fedids, and provides utility methods for querying against the permissionable data served by the `bundle server` from this repository. The resolution of these dependent rules may require the use of the [OPA Dependency Management](https://github.com/johanfylling/opa-dependency-manager/) tool: use of this policy bundle is not required, and code snippets from `org-policy` may currently be preferable until the situation settles.

## Adding dependencies

Note: Currently ODM does not support OCI dependencies  
Note: Currently ODM does not support subpaths within a repository

As the above prevents depending directly on the org-policy within this repository, this how-to section is to be considered preliminary, for guidance and a target for future development.

Using `odm init` to create the basic `opa.project` yaml file that will hold configuration data about our dependent package, ODM prescribes a folder structure of `src/` and `test/` and defines dependencies within a generated namespace: here we disable the namespacing of dependencies to make more readable imports.

```yaml
name: my_service_policy
source: src
tests: test
dependencies:
    diamond_policy:  # Git dependency on main of DLS/Authz repository TODO: Make OCI dependency
        location: git+https://github.com/DiamondLightSource/authz/tree/main/org-policy
        namespace: false
build:
    entrypoints:
    - "my.service.policy.allow"
```

Note: If generating an OCI bundle, we also require to expose the roots of the dependent package in our `.manifest` file.

## Writing policy

Below is an example of rego policy that uses a dependent package `diamond.policy` which defines granular authorization rules: it is assumed that the dependent package defines two methods: `can_read_from_session(proposal_number, session_number)` and `can_write_to_session(proposal_number, session_number)`. 

If the `diamond.policy` bundle and `diamond.data` bundle (from the bundle server) are both loaded, they are accessible under `data.diamond.<policy|data>`

In this example the policy is being used for an example service which serves data over HTTP:

- The path `service.diamond.ac.uk/$proposalNumber/$visitNumber` lists a collection of data files, collected on the visit.  
- The path `service.diamond.ac.uk/$proposalNumber/$visitNumber/$fileName` downloads a file from the service.

It is assumed that the user has already been authenticated, and user authentication information is contained within the headers of the request. The exact form of the authentication information, and how to parse it is left to the `diamond.policy` package to define. The `input` to the OPA instance might include the following structure:

Note: The following structure is that returned by the [fastapi-opa](https://pypi.org/project/fastapi-opa/) middleware. An example of the structure from your chosen solution may be available with its documentation: e.g. the OPA-Envoy ext_authz filter uses "parsed_path" instead of "request_path".

```json
{
  "request_path": [
    "$proposalNumber",
    "$visitNumber",
    "$fileName"
  ]
}
```

Assuming that a "session" can be uniquely identified from a proposal number and visit number, and that this session is sufficient to tell which paths a user can access, the following policy:

1. By default: sets that the user is not allowed to access any paths
2. If `input.request_path` is defined, is at least 2 elements long, and `can_read_from_session(input.request_path[0], input.request_path[1])` is true, allows the request

```rego
package my_policy

import rego.v1
import data.diamond.policy.can_read_from_session

# METADATA
# description: 'Allow a user to access their own data'
# entrypoint: true
default allow := false

allow if {
	can_read_from_session(input.request_path[0], input.request_path[1])
}
```

This allows a user on a session to both see all the files on that session and download these files, as `can_read_from_session` remains true when `request_path[2]` exists and is the name of a data file. Considerations of rules effects on other endpoints should be an early concern, and multiple entrypoints may be useful to prevent leaking permissions when defining endpoints.

## Building Policy

Note: ODM does not currently have a github action

When building policy manually, first run `odm update`, which fetches all dependencies, then proceed as described in the [writing policy docs](write-policy.md)

