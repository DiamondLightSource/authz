# Defining and building policy bundles

## Preface

This guide will explain how to build rego language policy into a bundle which can be used as an entrypoint to your AuthZ decisions, the "Application Policy" referred to in the preface of the [configuring OPA how-to](configure-opa.md).

See also [the OPA documentation on Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) and the [opa playground](https://play.openpolicyagent.org/).

## Writing policy

Below is an example of rego policy that uses a dependent package named `diamond` which defines granular authorization rules: it is assumed that the dependent package defines two methods: `user_on_session(proposalNumber, visitNumber)` and `user_on_proposal(proposalNumber)`. While OPA typically expects all policy to be defined within a single bundle, in an attempt to abstract the moving target of Diamond Authentication and to simplify adoption, these functions will be defined in `org-policy` in this repository and made available to write policy against.

In this example the policy is being used for an example service which serves data over HTTP:

- The path <service.diamond.ac.uk/$proposalNumber> lists a number of sessions, which a user should only be able to see if they are on the proposal.  
- The path <service.diamond.ac.uk/$proposalNumber/$visitNumber> lists a collection of data files, which the user should only be able to see if they are on the session.  
- The path <service.diamond.ac.uk/$proposalNumber/$visitNumber/$fileName> downloads a file from the service, if the user is on its session.

It is assumed that the user has already been authenticated, and user authentication information is contained within the headers of the request. The exact form of the authentication information, and how to parse it is left to the `diamond` package to define. The `input` to the OPA instance would include the following structure:


```json
{
  "attributes": {
    "request": {
      "http": {
        "host": "service.diamond.ac.uk",
        "method": "GET",
        "path": "/$proposalNumber/$visitNumber/$fileName"
      }
    }
  },
  "parsed_path": [
    "$proposalNumber",
    "$visitNumber",
    "$fileName"
  ],
  "parsed_query": {}
}
```

Assuming that the proposal number is sufficient to tell which paths a user can access, the following policy:

1. By default: sets that the user is not allowed to access any paths
2. If `input.parsed_path[0]` is defined and `user_on_proposal(input.parsed_path[0])` is true, allows the request

```rego
package my_policy

import rego.v1
import data.diamond.user_on_proposal
import data.diamond.user_on_session

# METADATA
# description: 'Allow a user to access their own data'
# entrypoint: true
default allow := false

allow if {
	user_on_proposal(input.parsed_path[0])
}
```

If however, there are sessions within a proposal that the user should not be able to see data from, we extend the requirements of our `allow` clause. Now `allow` is only `true` if `input.parsed_path[0]` is defined and `user_on_proposal(input.parsed_path[0])` is `true` and either definition of `can_see_visit` is `true`: i.e., there is no visit on the path, or the user is on that session.

Note how adding an additional clause in the `allow` definition means that `allow` is `true` only if every clause in its block is defined and `true`, while defining an additional `can_see_visit` block means that `can_see_visit` is `true` if any definition of `can_see_visit` is `true`.

```rego
allow if {
	user_on_proposal(input.parsed_path[0])
	can_see_visit
}

can_see_visit if {
	user_on_session(input.parsed_path[0], input.parsed_path[1])
}

can_see_visit if {
	count(input.parsed_path) == 1
}
```

## Testing Policy

- Tests for policy should be defined in `foo_test.rego` if they are testing functionality from module `foo.rego`.
- Tests should be in a package `bar` if they are testing policy in package `bar`.
- Test cases within `foo_test.rego` must be named `test_*`.

The following test file mocks the `data.diamond.user_on_proposal` function for testing and checks that by default a request is denied.

```rego
package my_policy

import rego.v1

user_on_proposal(proposalNumber) if {
	proposalNumber = "0"
}

test_default_disallowed if {
	not allow with input as {} with data.diamond.user_on_proposal as user_on_proposal
}

test_allow_user_on_proposal if {
	allow with input as {"parsed_path": ["0"]} with data.diamond.user_on_proposal as user_on_proposal
}
```
The following github action workflow:

- Runs on every pull_request or push to a branch (but only once)
- Lints the policy in `org-policy` directory using the `regal` rego linter
- Runs any tests in the `org-policy` directory

```yaml
name: Policy Test

on:
  push:
  pull_request:

jobs:
  lint:
    # Deduplicate jobs from pull requests and branch pushes within the same repo.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4.1.1

      - name: Setup Regal
        uses: StyraInc/setup-regal@v0.2.0
        with:
          version: latest

      - name: Lint
        run: regal lint --format github ./org-policy

  test:
    # Deduplicate jobs from pull requests and branch pushes within the same repo.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4.1.1

      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2.1.0
        with:
          version: latest

      - name: Test
        run: opa test ./org-policy -v
```

## Building OPA policy

The following github action

- Runs on every pull_request or push to a branch (but only once)
- Builds all policy in `org-policy` directory, except that in files matching `*_test.rego` (i.e., excluding any tests)
- If the push to a branch had a tag created for the repository, creates an OCI bundle that is release on the Github Container Registry [for consumption by a configured instance](configure-opa.md)

```yaml
name: Policy Container

on:
  push:
  pull_request:

jobs:
  build_bundle:
    # Deduplicate jobs from pull requests and branch pushes within the same repo.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout source
        uses: actions/checkout@v4.1.1

      - name: Generate Image Name
        run: echo IMAGE_REPOSITORY=ghcr.io/$(echo "${{ github.repository }}-policy" | tr '[:upper:]' '[:lower:]' | tr '[_]' '[\-]') >> $GITHUB_ENV

      - name: Log in to GitHub Docker Registry
        uses: docker/login-action@v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2.1.0
        with:
          version: latest
      
      - name: Build OPA Policy  # If this is a tag, use it as a revision string
        run: opa build -b org-policy -r ${{ github.ref_name }} --ignore *_test.rego

      - name: Publish OPA Bundle
        if: ${{ github.event_name == 'push' && startsWith(github.ref, 'refs/tags') }}
        run: oras push ${{ env.IMAGE_REPOSITORY }}:${{ github.ref_name }} bundle.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
```