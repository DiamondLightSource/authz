# Diamond AuthZ

User docs available on [GitHub pages](https://diamondlightsource.github.io/authz)

A collection of things required to add authorization to applications using Open Policy Agent (OPA), including:
- [`bundler`](./bundler/): A OPA compliant bundle server which presents permissionable data from ISPyB as an OPA bundle - [docs](https://diamondlightsource.github.io/authz/bundler)
- [`charts/bundler`](./charts/bundler/): A Helm chart for deploying the central `bundler` instance
- [`charts/opa`](./charts/opa/): A Helm chart for deploying an application OPA instance
- [`org-policy`](./org-policy/): A collection of common policy fragments which implement organisational level policy decisions
