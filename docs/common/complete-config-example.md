<!-- markdownlint-disable MD041 -->
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