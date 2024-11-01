# Deploy Docker Compose

## Preface

This guide will explain how to deploy Open Policy Agent (OPA) as part of your local development environment using `docker-compose`. Such deployments are often used as part of [Devcontainer](https://containers.dev/) development environments to provide additional services.

## Configure OPA

To begin, you should configure your OPA instance to retrieve the desired bundles. Please see [How To Configure OPA](configure-opa.md) for guidance on the values supplied in each of these fields.

The example below makes use of the [Diamond Data Bundle](../references/diamond-data-bundle.md) and [Organisational Policy](../references/organisational-policy.md) to baseline policies endpoints, upon which you can build your application specific policy.

!!! note

    Local policy which may be actively developed should not be included in the configuration file, instead it should be mounted into the OPA container and included using the `--watch` argument on the command.

!!! example 

    ```yaml title="opa.yml"
    services:
      bundler:
        url: https://bundler.diamond.ac.uk
        credentials:
          bearer:
            token: ${BUNDLER_BEARER_TOKEN}
      ghcr:
        url: https://ghcr.io
        type: oci
    bundles:
      diamond-data:
        service: bundler
        resource: bundle.tar.gz
        polling:
          min_delay_seconds: 10
          max_delay_seconds: 60
      organisational-policy:
        service: ghcr
        resource: ghcr.io/diamondlightsource/authz-policy:latest
        polling:
            min_delay_seconds: 30
            max_delay_seconds: 120
    ```

## Add to docker-compose

You may now add the OPA instance to your `docker-compose` configuration, using the `docker.io/openpolicyagent/opa` image with the latest stable tag. You should mount in the config file from [Configure OPA](#configure-opa) using the `volumes` list and set the `command` to `run --server --config-file /<YOUR_CONFIG>.yml`.

### Using the Diamond Data Bundle

If using the [Diamond Data Bundle](../references/diamond-data-bundle.md) you should create an envionment variable file (`opa.env`) containing the `BUNDLER_BEARER_TOKEN` environment variable and mount this using the `env_file` option.

### Using the Organisational Policy

If using the [Organisational Policy](../references/organisational-policy.md) you should set the `JWKS_ENDPOINT` environment variable to the KeyCloak JSON Web Key Set (JWKS) endpoint - `https://authn.diamond.ac.uk/realms/master/protocol/openid-connect/certs` - using the `environment` list.

### Using Local Policy

To utilize local policy you should mount in the policy volume and setting the `--watch` option in the command.

!!! example

    ```env title="opa.env"
    BUNDLER_BEARER_TOKEN=<BUNDLER_BEARER_TOKEN>
    ```

    ```yaml title="docker-compose.yml"
    version: "3.8"

    services:
      my-app:
        build:
          context: .
          dockerfile: Dockerfile
        volumes:
          - ..:/workspace:cached,z
        command: sleep infinity
        environment:
          OPA_URL: http://opa:8181
      opa:
        image: docker.io/openpolicyagent/opa:0.64.0
        restart: unless-stopped
        command: >
          run
          --server
          --config-file /config.yml
          --watch /policy
        volumes:
          - ./opa.yml:/config.yml:cached,z
          - ../policy:/policy:cached,z
        environment:
          JWKS_ENDPOINT: https://authn.diamond.ac.uk/realms/master/protocol/openid-connect/certs
        env_file: opa.env
    ```
