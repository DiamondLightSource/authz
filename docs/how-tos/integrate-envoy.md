# Integrate with Envoy

## Preface

This guide will explain how to delegate authorization decisions to OPA form a Istio proxy using the [OPA Envoy plugin](https://www.openpolicyagent.org/docs/latest/envoy-introduction/).

!!! note

    This guide assumes you have deployed an OPA instance with a system package as described in the [policy writing guide](write-policy.md) - see the [Helm](deploy-with-helm.md) or [docker-compose](deploy-docker-compose.md) deployment guide for instructions on OPA deployment.

## Add the OPA Envoy Plugin

OPA must be deployed with the [Envoy Plugin](https://www.openpolicyagent.org/docs/latest/envoy-introduction/) - this enables a gRPC endpoint which is mapped to one of your policies. If running from a container, the `docker.io/openpolicyagent/opa:0.64.0-envoy` image should be used in place of the regular image. Your OPA configuration should be modified to include the following:

```yaml
plugins:
  envoy_ext_authz_grpc:
    path: path/to/your/policy/root
```

!!! tip "Modifying your helm deployment"

    The helm deployment can be switched to use the envoy image by setting `image.envoy` to `true` whilst the confiuration change can be included in `opa.extraConfig`, like:

    ```yaml
    image:
      envoy: true
    opa:
      extraConfig:
        plugins:
          envoy_ext_authz_grpc:
            path: path/to/your/policy/root
    ```

## Installing the External Authorization EnvoyFilter into the Envoy instance

An Envoy sidecar checks all incoming traffic against a series of filters, adjusting, allowing or rejecting traffic accordingly. The following configures an external authorization filter that will check all incoming traffic, passing the headers and path (and optionally the body of the request) to your OPA instance configured above.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: authz-envoyfilter
spec:
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          filterChain:
            filter:
              name: "envoy.filters.network.http_connection_manager"
              subFilter:
                name: "envoy.filters.http.router"
      patch:
        operation: INSERT_BEFORE
        filterClass: AUTHZ
        value:
          name: envoy.ext_authz
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
            transport_api_version: V3
            status_on_error:
              code: ServiceUnavailable
            grpc_service:
              google_grpc:
                target_uri: <YOUR_OPA_DOMAIN>:9191
                stat_prefix: "ext_authz"
```
