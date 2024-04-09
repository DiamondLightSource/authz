# Build & Package Policy

## Preface

This guide will explain how to build and package a OPA Bundle from your policy. The bundle will be exported in OCI format, allowing publishing to an OCI registry.

!!! tip

    See also:

    - [OPA Bundle Build Command](https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-build)
    - [OPA OCI Registry Compatibility](https://www.openpolicyagent.org/docs/latest/management-bundles/#oci-registry)
    - [OPA Bundle Format](https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-file-format)

## Bundle Manifest

OPA OCI Bundles must contain a JSON formatted Manifest file (`.manifest`) which describes the bundle contents. This file must include the package roots - a list of package paths which the bundle provides.

!!! example

    **`.manifest`**:
    ```json
    {
        "roots": ["system", "my/helper"]
    }
    ```

## Building Policy

The OPA Bundle can be built using the [`opa build`](https://www.openpolicyagent.org/docs/latest/cli/#opa-build) command. The policy bundle we are building is supplied using the `--bundle` option with the version given using the `--revision` option. If your policy package contains tests then you should ignore them using `--ignore *_test.rego`. This should produce a file of the form ``.

!!! example

    ```shell
    opa build --bundle policy/ --revision v1.2.3 --ignore *_test.rego
    ```

## Publishing Policy

The OCI image can be created an published using the [`oras push`](https://oras.land/docs/commands/oras_push) command. The first argument of the command is the registry which the image is to be pushed to whilst the second argument is the file to include in the image and the custom media type to use - this should be the file produced by `opa build` followed by `:application/vnd.oci.image.layer.v1.tar+gzip`.

!!! example

    ```shell
    oras push localhost:5000/policy:v1.2.3 bundle.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
    ```

## Continious Delivery

It is strongly recommended you implement policy packaging as part of your Continious Integration (CI) and Continious Delivey (CD) pipelines, an example for doing this in GitHub Actions is shown below.

!!! example "Github action for building and releasing OPA policy as OCI bundle on GHCR"

    ```yaml
    {%
          include "../../.github/workflows/policy-container.yml"
    %}
    ```
