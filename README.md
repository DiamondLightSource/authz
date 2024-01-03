# Policy Admin

A collection of things required to add authorization to applications using Open Policy Agent (OPA), including:
- [`bundler`](./bundler/): A OPA compliant bundle server which presents permissionable data from ISPyB as an OPA bundle - [docs](https://diamondlightsource.github.io/authz/bundler)
- [`charts/bundler`](./charts/bundler/): A Helm chart for deploying the central `bundler` instance
- [`charts/opa`](./charts/opa/): A Helm chart for deploying an application OPA instance
- [`org-policy`](./org-policy/): A collection of common policy fragments which implement organisational level policy decisions

## Configuring an OPA instance to make use of data served by the Bundle Server and built org-policy

An OPA instance, either running as a central instance or as the sidecar to a container that requires Authorization decisions can be configured to get bundles from multiple sources, including polling the bundle server built in this repository for updated data.
It is assumed that policy specific for your service is also built into an OCI bundle, additional to the below configuration.

This OPA instance must be configured with the Bearer token required for polling the Bundle Server as an environment variable named BUNDLE_BEARER_TOKEN.

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
    resource: ghcr.io/diamondlightsource/authz-policy  # Use an appropriate version
```

## Configuring an EnvoyFilter to use an OPA sidecar as an ext-authz provider

An EnvoyFilter is a Kubernetes Custom Resource Definition which may be enabled if the Istio Service Mesh is installed into your cluster. 
Here we make use of its capability to defer authz decisions to an external service to use an OPA instance deployed as a sidecar to your service as such an authz decision provider.

Important Note:
To make use of OPA as an external authz provider for Envoy, the following addition must be made to the config.yaml of the instance

```yaml
plugins:
  envoy_ext_authz_grpc:
    path: root/decision/of/your/policy
```

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
            # with_request_body: # If you require details of the request to make the AuthZ decision
            #   max_request_bytes: 8192
            #   allow_partial_message: true
            grpc_service:
              # EnvoyGrpc has issue with requiring http2, use of GoogleGrpc seems to be standard
              google_grpc:
                target_uri: 0.0.0.0:9191
                stat_prefix: "ext_authz"
```

As this project allows for Authorization rules to be written against internal Diamond Authentication information, it is assumed that Authentication is already handled in the ServiceMesh and incoming traffic is already authenticated. 
The following additions to the deployment spec of your service 

- Enable the Service Mesh injecting an Envoy Sidecar, which intercepts all inbound traffic and passes it through any configured EnvoyFilters
- Configures an OPA instance as an additional sidecar to the container, which will handle any AuthZ decisions passed to it by the EnvoyFilter

```yaml
spec:
  template:
    metadata:
      labels:
        sidecar.istio.io/inject: 'true'
    spec:
      containers:
        - image: "openpolicyagent/opa:latest-istio"
          name: "opa-istio"
          env:
          - name: BUNDLE_BEARER_TOKEN
            valueFrom:
              secretKeyRef:
                name: bundle-server-token
                key: bearer-token
          volumeMounts:
          - name: "opa-config"
            mountPath: "/config"
          args:
            - run
            - --server
            - --diagnostic-addr=:8282  # Required if using liveness/readiness probes on OPA instance
            - -c
            - /config/config.yaml
      volumes:
        - name: opa-config
          configMap: 
            name: opa-config
```
