# Deploy with Helm

## Preface

This guide will explain how to deploy Open Policy Agent (OPA) as part of your Helm-managed Kubernetes deployment.

## Add the Chart Dependency

To use the OPA instance in your deployment you should add the following to the `dependencies` section in your `Chart.yaml`:

```yaml
- name: opa
  version: 0.1.0
```

You may additionally wish to add a condition, e.g. `opa.enabled`. If added you will need to set the corresponding value to true when you [Configure your Values](#configure-values)

## Configure Values

The default values of the chart will deploy a single OPA instance which serves the latest Diamond Policy with Permissonable Data from the bundler.

You will likely want to modify the `opa.config` entry to include the policy bundle for your application, see [How To Configure OPA](configure-opa.md) for instructions on creating an appropriate configuration.

!!! example "Complete Configuration"

    {%
        include-markdown "../common/complete-config-example.md"
        heading-offset=1
    %}

If you expect a your service to experience a significant load or require high availability you may wish to scale up the number of instances available by setting `replicaCount` to a value greater than `1`. Additionally, autoscaling can be enabled with `autoscaling.enable` and configured with the minimum and maximum number of instances determined by `autoscaling.minReplicas` and `autoscaling.maxReplicas` respectively.
