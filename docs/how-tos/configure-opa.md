# Configure OPA

## Preface

This guide will explain how to configure Open Policy Agent (OPA) to fetch the data & policy nessacary to make authorization decisions for your application at Diamond. Typically the following three `bundles` are required:

- Permissionable Data - containing data about what a given user has access to and is permitted to do
- Diamond Policy - containing high level organisational level rules
- Application Policy - containing your application specific rules

## Permissionable Data Bundle

The Permissionable Data bundle is derived from the contents of the `ISPyB` database and is made available by the `bundler` service which sits behind `https://authz.diamond.ac.uk`. The service currently requires a `Bearer Token` for authorization - which can be obtained by reaching out via the [`#auth_auth` slack channel](https://diamondlightsource.slack.com/archives/C03P6QB9589) - but will switch to using tokens from the central authentication service once device flow is supported. The following service configuration should therefore be used:

```yaml
services:
    diamond-bundler:
        url: https://authz.diamond.ac.uk
        credentials:
            bearer:
                token: ${BUNDLE_BEARER_TOKEN}
```

From this service we will then fetch the `bundle.tar.gz` resource - which is an [OPA bundle file](https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-file-format) containing the permissionable data. You should poll for this on a regular basis, between `10` and `60` seconds is considered a reasonable value. The following bundle configuration should therefore be used:

```yaml
bundles:
    diamond-permissionables:
        service: diamond-bundler
        resource: bundle.tar.gz
        polling:
            min_delay_seconds: 10
            max_delay_seconds: 60
```

## Diamond Policy Bundle

The Diamond Policy bundle contains a set of common rules for authorization and is hosted on the GitHub Container Registry (GHCR) in Open Containers Initiative (OCI) format. You should poll for this on a regular basis, between `30` and `120` seconds is considered a reasonable value. The following service configuration should therefore be used:

```yaml
services:
    ghcr:
        url: https://ghcr.io
        type: oci
```

The fully qualifed path of the OCI image - `ghcr.io/diamondlightsource/authz-policy:latest` - must be used. The following bundle configuration should therefore be used:

```yaml
bundles:
    diamond-policies:
        service: ghcr
        resource: ghcr.io/diamondlightsource/authz-policy:latest
        polling:
          min_delay_seconds: 30
          max_delay_seconds: 120
```

## Application Policy Bundle

Assuming your application is also hosted on GitHub you can upload your policy bundle to `ghcr` and re-use the service from the [diamond policy bundle section](#diamond-policy-bundle). Similarly to before, the fully qualifed path of the OCI image - e.g. `ghcr.io/diamondlightsource/your-application-policy:latest` - must be used. You should poll for this on a regular basis, between `30` and `120` seconds is considered a reasonable value. The following bundle configuration should therefore be used:

```yaml
bundles:
    application-policies:
        service: ghcr
        resource: ghcr.io/diamondlightsource/your-application-policy:latest
        polling:
          min_delay_seconds: 30
          max_delay_seconds: 120
```

!!! example "Complete Configuration"

    ```yaml
    services:
        diamond-bundler:
            url: https://authz.diamond.ac.uk
            credentials:
                bearer:
                    token: ${BUNDLE_BEARER_TOKEN}
        ghcr:
            url: https://ghcr.io
            type: oci
    bundles:
        diamond-permissionables:
            service: diamond-bundler
            resource: bundle.tar.gz
            polling:
                min_delay_seconds: 10
                max_delay_seconds: 60
        diamond-policies:
            service: ghcr
            resource: ghcr.io/diamondlightsource/authz-policy:latest
        application-policies:
            service: ghcr
            resource: ghcr.io/diamondlightsource/your-application-policy:latest
    ```
