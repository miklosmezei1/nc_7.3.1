# Resource requests and limits

It is possible to specify resource requests and limits for all deployments of the Enterprise-AIO
chart.
By default there are no requests and limits configured as the actual values depend on the number of
total and concurrent users.
Please contact your account manager in case you need infrastructure recommendations for your
Nextcloud server.

## Process steps

1. Reach out to your Sales Engineer
1. Configure built-in services
1. Configure Nginx subchart
1. Upgrade the installed Helm chart

## Details
--- PREVIEW ---

### Reach out to your Sales Engineer
Before configuring the values, please reach out to your assigned Sales Engineer to request the values that you want to configure here.

### Configure built-in services

Start by editing your local `values.yaml` file of your installed chart.
There are multiple `*_RESOURCES` values available, one for each deployment.

The expected format should be a yaml dictionary with one top level key for requests and one for
limits.
Usually, the memory and cpu resources are specified.
Here is an example for the built-in redis deployment:

```yaml
REDIS_RESOURCES:
  requests:
    memory: "128Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "2000m"
```

The format is the same for all resource values.

Please have a look at the
[official Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-units-in-kubernetes)
for more information on the resource units.

### Configure Nginx subchart

The nginx subchart can be adjusted by either using a preset defined by the Bitnami authors or
manually specifying limits.

By default, the medium preset is applied to Nginx.
Please have a look
[here](https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl) for
more information about the available presets.

```yaml
nginx:
  resourcesPreset: medium
```

Otherwise, you may use `resources` key instead of `resourcesPreset` in case you want to specify the
limits and requests manually.

```yaml
nginx:
  resources:
    requests:
      memory: "64Mi"
      cpu: "250m"
    limits:
      memory: "2048Mi"
      cpu: "2000m"
```

### Upgrade the installed Helm chart

When you are done with adjusting values, you may continue with upgrading your installed Helm chart.
The command depends on your preferred deployment method.

If the Helm chart is checked out via git or extracted from an archive, the command is usually:

`helm upgrade -f values.yaml <name-of-installation> <path-to-chart>`

If the chart is deployed via the OCI artifact, the command should look something like:

`helm upgrade -f values.yaml --version 3.0.0 <name-of-installation> oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart`

**Warning:** Adding or modifying resource requests or limits involves restarting all associated
Pods! Expect there be a short downtime while the Pods are being restarted.
