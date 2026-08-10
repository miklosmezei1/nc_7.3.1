# Annotations and labels for the deployments

It is possible to specify additional annotations and labels for all deployments of the Enterprise-AIO chart.

## Process steps

1. Adjust annotations and labels in `values.yaml`.
1. Upgrade the installed Helm chart.

## Details
--- PREVIEW ---

### Built-in services

Start by editing your local `values.yaml` file of your installed chart.
There are multiple `*_ADDITIONAL_ANNOTATIONS_AND_LABELS` values available, one for each deployment.

The expected format should be a yaml dictionary with one top level key for annotations and one for labels.

Here is an example for the built-in redis deployment:

```yaml
REDIS_ADDITIONAL_ANNOTATIONS_AND_LABELS:
  annotations:
    annotation1: "value1"
    annotation2: "value2"
  labels:
    label1: "value1"
    label2: "value2"
```

The format is the same for all `*_ADDITIONAL_ANNOTATIONS_AND_LABELS` values.

### Nginx subchart

The nginx subchart can be adjusted by using the following values:
```yaml
nginx:
  podLabels:
    io.kompose.service: nextcloud-enterprise-nginx # This is required for the system to work correctly, so do not modify this!
    additional-label1: value1
  podAnnotations:
    additional-anntotation1: value1
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
