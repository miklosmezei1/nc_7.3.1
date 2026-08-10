# OpenShift Overview

Running Enterprise AIO on OpenShift is a work in progress. To do so, you need to adjust some values inside the `values.yaml` file. Also please note that some of the bundled containers are not able to run on OpenShift due to required capabilities.

1. Adjust values
1. Configure ingress / Route
1. Install the Helm chart

--- PREVIEW ---

## Status

The deployment and most features are known to work, including Nextcloud itself, most Nextcloud apps, database, Redis, desktop and browser notifications, and also additional optional bundled containers (unless mentioned in the following).

*Known not to work* due to fundamental issues are the bundled containers for Office (Collabora and OnlyOffice), and fulltext search. Both of these can be set up using external charts. Please read our documentation on a [scalable full Nextcloud Hub installation](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#scalable-full-nextcloud-hub-installation) for details and instructions.

Also not yet supported is Openshift's internal Ingress controller.


## Adjust values

In order to run E-AIO securely on OpenShift, you need to adjust the following values:

```yaml
USE_SECRETS: "yes" # This allows to use secrets. You need to configure these according to https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/How-to-use-secrets 
NETWORK_POLICY_ENABLED: "yes" # This enables a compatible network policy config inside the chart.
VPA_ENABLED: "no" # This means that the Vertical Pod Autoscaler is deactivated. In that case you need to configure resources manually. See the `*_RESOURCES` variables mentioned below.
RPSS_ENABLED: "yes" # This means that the restricted Pod Security Standard is enforced. Please note that some bundled containers like collabora, fulltextseach and onlyoffice do not support this. If you still want to use these, you need to install these externally and connect them via values.yaml. See https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#scalable-full-nextcloud-hub-installation
NEXTCLOUD_UGID: &NEXTCLOUD_UGID 1001 # Use a value from inside your uid-range and supplemental-groups
REDIS_UGID: 1002 # Use a value from inside your uid-range and supplemental-groups
POSTGRES_UGID: 1003 # Use a value from inside your uid-range and supplemental-groups
TALK_RECORDING_UGID: 1004 # Use a value from inside your uid-range and supplemental-groups
IMAGINARY_UGID: 1005 # Use a value from inside your uid-range and supplemental-groups
CLAMAV_UGID: 1006 # Use a value from inside your uid-range and supplemental-groups
TALK_UGID: 1007 # Use a value from inside your uid-range and supplemental-groups
WHITEBOARD_UGID: 1008 # Use a value from inside your uid-range and supplemental-groups
*_RESOURCES: # This is a placeholder for all the different Resources variables. You need to configure these according to https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/Resource-requests-and-limits
STORAGE_CLASS: "your-storage-class" # By setting this, you can adjust the storage class for your volumes. This should be a fast storage like SSD backed storage!
STORAGE_CLASS_DATA: "your-storage-class-for-huge-data" # Allows to set a dedicated storage class for the Nextcloud data volume. This can be a bit slower storage than the one above. ⚠️ Warning: only set this for new installations, not existing ones!
*_STORAGE_SIZE: # This is a placeholder for all the different storage size variables. You need to configure these according to https://github.com/nextcloud-gmbh/enterprise-aio/blob/main/nextcloud-enterprise-helm-chart/values.yaml
NFS_SERVER: # This needs to be empty to use PVCs
HOST_PATH: # This needs to be empty to use PVCs
# Enable Nginx with these options and review the rest of the `nginx`-section in the shipped values.yaml.
APACHE_HOST: &APACHE_HOST nextcloud-enterprise-nginx
nginx:
    enabled: true
```

Please note that this is a short overview of available and recommended settings for OpenShift. There are further configuration options that you might want to adjust.

### Airgapped installation

If the cluster does is not connected to the internet, please read [Airgapped installation](./Airgapped-installation).

## Configure ingress / Route

OpenShift ships with a built-in HAProxy-based ingress router that uses the native `Route` resource (`route.openshift.io/v1`). This chart supports both approaches:

| Approach | Value to set | When to use |
|---|---|---|
| OpenShift default Route | `OPENSHIFT_ROUTE_ENABLED: "yes"` | OpenShift clusters using the built-in HAProxy router (most common) |
| Standard Kubernetes Ingress | `INGRESS_ENABLED: "yes"` | OpenShift clusters where a third-party ingress controller (e.g. ingress-nginx) was installed |

⚠️ Do **not** set both `OPENSHIFT_ROUTE_ENABLED` and `INGRESS_ENABLED` to `"yes"` at the same time.

### Using the OpenShift default Route (recommended)

Set the following values in your `values.yaml`:

```yaml
OPENSHIFT_ROUTE_ENABLED: "yes"  # Enables the OpenShift Route resource
NGINX_ENABLE_HSTS: "no"         # HSTS is handled by the Route's edge TLS termination
```

The chart will create a `Route` object with:
- **Edge TLS termination** — HTTPS is terminated at the HAProxy router; traffic to the Apache pod is plain HTTP.
- **HTTP → HTTPS redirect** — Any plain-HTTP request is automatically redirected to HTTPS.
- **Large upload support** — The `haproxy.router.openshift.io/proxy-body-size` annotation is set to `APACHE_MAX_SIZE` (default `17179869184` bytes / 16 GiB).
- **Long-running request timeout** — The `haproxy.router.openshift.io/timeout` annotation is set to `NEXTCLOUD_MAX_TIME` seconds (default `3600`), which covers large file uploads.
- **WebSocket support** — A generous websocket session timeout is configured for Nextcloud Talk and notify_push.

#### Supplying your own TLS certificate

By default the OpenShift router issues a TLS certificate automatically using the cluster's wildcard certificate. We recommend to use cert-manager instead to use publicly trusted certificates for the connection. See [cert-manager OpenShift Routes](https://cert-manager.io/docs/configuration/acme/#solving-challenges) integration to automate certificate issuance via Let's Encrypt.

### Using a third-party ingress controller on OpenShift

If you installed ingress-nginx or another ingress controller on your OpenShift cluster, use the standard ingress support instead:

```yaml
INGRESS_ENABLED: "yes"
INGRESS_CLASS_NAME: "nginx"         # or the class of your installed controller
INGRESS_CLUSTER_ISSUER: "letsencrypt-prod"  # optional, requires cert-manager
```

See the [scalable-nginx](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/scalable-nginx) directory for example values files for both ingress-nginx and the NGINX Ingress Controller.

## Install the Helm chart

Install the helm chart by following the documentation [here](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#how-to-use-this).
