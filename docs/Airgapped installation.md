# Enterprise-AIO - Airgapped installation

The Enterprise-AIO Helm chart can be operated offline/airgapped.

## Process steps

1. Preparation
1. Download the Helm chart
1. Download images into a private registry
1. Download archives to a PVC or NFS mount
1. Configure additional values
1. Install the Helm chart
1. Optional: Configure external reverse proxy

## Details
--- PREVIEW ---

#### Preparation

#### Download the Helm chart

Download the Helm chart by following the documentation [here](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#how-to-use-this).

#### Download images into a private registry

Navigate the folder nextcloud-enterprise-helm-chart.
The following bash script will create a list of all required images to be pushed to a private registry.

```
grep -rh 'image:' templates | \
	sed -e 's/{{ .Values.NEXTCLOUD_IMAGE_ORG }}/nextcloud/g' \
		-e 's/{{ .Values.IMAGE_MIRROR_PREFIX }}//g' \
		-e 's/{{ .Values.ALPINE_IMAGE_ORG}}/library/g' | \
	sed -n 's/.*image:[[:space:]]*"*\([^"]*\)"*/\1/p' | \
	sort | uniq
```

#### Download archives to a PVC or NFS mount

Configure the archives PVC or NFS mount as described in [our documentation](https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/values.yaml-ARCHIVES_PVC_NAME-for-local-archives).

#### Configure additional values

Navigate the folder nextcloud-enterprise-helm-chart.

Configure the `values.yaml` file.  
At least, all !TODO values need to be changed.

Special settings need to be done for air-gapped:

- `IMAGE_MIRROR_PREFIX`: Setting this allows you to pull Nextcloud images through a mirror registry. It needs a trailing slash!
- `NEXTCLOUD_IMAGE_ORG`: Setting this allows you to change the image's org name in case a different image needs to be used e.g. for compliance reasons.
- `NC_DOMAIN`: set this to your public domain of your ingress or external reverse proxy for which you have a valid public and globally trusted TLS certificate (not self-signed nor internal)
- `NEXTCLOUD_STARTUP_APPS`: Remove anything besides "twofactor_totp"
- `AIRGAPPED: "yes"` => This will preconfigured Nextcloud accordingly

Now, the ingress feature can be configured by following the documentation [here](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/scalable-nginx).

In case the scalable Nginx sub-chart is being used you need to push the sub-chart's images to a
private registry as well:
- `nginx.image.registry`: Set this if you use a custom registry (default: ghcr.io)
- `nginx.image.repository`: Set this if you use a custom repository (default: nextcloud-releases/nce-nginx)

#### Install the Helm chart

Install the helm chart by following the documentation [here](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#how-to-use-this).

#### Optional: Configure external reverse proxy

If no ingress feature is used, you can still run the chart by configuring an external reverse proxy.

To make that work you can expose the scalable Nginx sub-chart on your cluster by following the
documentation [here](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/scalable-nginx#optional-external-reverse-proxy-instead-of-ingress).

It is assumed that you have a valid public and globally trusted TLS certificate (not self-signed nor internal) to make all sub-services work, for example, Collabora etc.

The external reverse proxy then needs to terminate TLS traffic on your domain on port 443 and redirect it to the internal IP address and port from the Nginx service.
