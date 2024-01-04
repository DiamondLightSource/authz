# Deploy with Helm

## Preface

This guide will explain how to deploy Open Policy Agent (OPA) as part of your Helm-managed Kubernetes deployment.

By default, this deployment will attempt to pull the [Diamond Data Bundle](../references/diamond-data-bundle.md) from the Bundler but will not include the organisational policy or your application policy and data.

 - To use the [Diamond Data Bundle](../references/diamond-data-bundle.md) you must supply a access token as described in [Using the Diamond Data Bundle](#using-the-diamond-data-bundle).
 - To use the Organisational Policy you must enable it as described in [Using the Origanisational Policy](#using-the-organisational-policy).
 - To use your own application policy or data you must add it as an addtional bundle as described in [Adding Addtional Bundles](#adding-additional-bundles).

## Add the Chart Dependency

To use the OPA instance in your deployment you should add the following to the `dependencies` section in your `Chart.yaml`:

```yaml
- name: opa
  version: 0.2.0
  repository: oci://ghcr.io/diamondlightsource/authz-opa
```

!!! tip

    You may wish to add a condition, e.g. `opa.enabled`. This will allow you to disable the deployment without editing your chart dependencies.

## Using the Diamond Data Bundle

By default the deployed OPA instance will attempt to retreive the [Diamond Data Bundle](../references/diamond-data-bundle.md) from the Bundler as explained in the [Data Flow Explanation](../explanations/data-flow.md). This behaviour can be toggled using the `opa.orgData.enabled` value.

 In order retrieve the bundle from the Bundler an access token must be supplied, the helm chart expects this to be supplied as a secret. By default, the chart expects a secret named `bundler` containing `bearer-token`. The token can be obtained by reaching out via the [`#auth_auth` slack channel](https://diamondlightsource.slack.com/archives/C03P6QB9589). To create the secret in your namespace simply run:

```bash
kubectl create secret generic bundler --from-literal=bearer-token=<BUNDLER_BEARER_TOKEN>
```

!!! note

    The secret name & key used to retrieve can be set via `opa.orgData.bundlerSecret.name` and `opa.orgData.bunderSecret.key` respectively.

!!! tip

    Sealed secrets can be used to securely store secrets alongside your configuration.

## Using the Organisational Policy

By default the deployed OPA instance will not load the [Organisational Policy](../references/organisational-policy.md), however this can be enabled by setting the `opa.orgPolicy.enabled` value to `true` in your `values.yaml`.

By default this will use the production CAS User Info Endpoint. If you wish to change this you should set the `opa.orgPolicy.userinfoEndpoint` value to the desired endpoint.


!!! example "values.yml"

    ```yaml
    opa:
        orgPolicy:
            enabled: true
            userinfoEndpoint: https://authbeta.diamond.ac.uk/cas/oidc/oidcProfile
    ```

## Adding Additional Bundles

Configuration for additional services and bundles can be supplied via the `opa.extraServices` and `opa.extraBundles` whilst extra environment variables can be supplied via the `opa.extraEnv` list. Please see [How To Configure OPA](configure-opa.md) for guidance on the values supplied in each of these fields.

!!! example "values.yml"

    ```yaml
    opa:
        extraServices:
            my-bundle-server:
                url: https://my-bundle-server
                credentials:
                    bearear:
                        token: ${MY_BUNDLE_SERVER_BEARER_TOKEN}
            gcr:
                url: https://gcr.io
                type: oci
        extraBundles:
            my-data:
                service: my-bundle-server
                resource: bundle.tar.gz
                polling:
                    min_delay_seconds: 10
                    max_delay_seconds: 60
            my-policy:
                service: gcr
                resource: gcr.io/diamond-pubreg/my-application/policy
                polling:
                    min_delay_seconds: 30
                    max_deplay_seconds: 120
        extraEnv:
            - name: MY_BUNDLE_SERVER_BEARER_TOKEN 
              valueFrom:
                name: my-bundle-server
                value: bearer-token
    ```

!!! note

    The `opa.extraConfig` value can be used to add additional configuration which is not for services or bundles whilst the `opa.configOverride` value can be used to completely replace the default configuration if required.
