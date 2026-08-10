# Enterprise-AIO with Podman in an offline scenario

The Enterprise-AIO can be operated offline/airgapped with Podman with some extra steps.
Note: *This is work-in-progress. Feedback is very welcome!*

## Process steps

1. Preparation
1. Ensure that Podman uses the `netavark` network backend
1. Prepare Helm Charts
1. Download images
1. Load images into podman
1. Configure additional values
1. Build the yaml files
1. Start the environment
1. Configure external reverse proxy
1. Cleanup

## Details
--- PREVIEW ---

#### Preparation

Install Podman >= 4.0 (required for the `netavark` network backend) on the online and the air-gapped server 

Install [Helm](https://helm.sh/docs/intro/install/) on the air-gapped server

Download the Nextcloud runtime archive from the customer portal and store it on a webserver that is reachable from the air-gapped server. Alternatively, use the new ARCHIVES_PVC_NAME variable. See our dedicated docu on the topic.

#### Ensure that Podman uses the `netavark` network backend

The process is documented [here](./Podman---Network-backend-netavark).

#### Prepare Helm Charts

Download the enterprise-helm-chart archive file from the GitHub repository (contact your Sales Engineer) and unpack.

Navigate into the folder nextcloud-enterprise-helm-chart.

Within the /templates folder, maintain the file nextcloud-enterprise-apache-deployment.yaml  
*(this is a temporary step - to be automated later)*

- below the line  
  "- containerPort: {{ .Values.APACHE_PORT }}"  
  add a line  
  "hostPort : {{ .Values.APACHE_PORT }}"

Within the /templates folder, maintain the file nextcloud-enterprise-talk-deployment.yaml  
*(this is a temporary step - to be automated later)*

- below the line  
  "- containerPort: {{ .Values.TALK_PORT }}"  
  "  protocol: TCP"
  add a line  
  "hostPort : {{ .Values.TALK_PORT }}"
- also, below the line  
  "- containerPort: {{ .Values.TALK_PORT }}"  
  "  protocol: UDP"
  add a line  
  "hostPort : {{ .Values.TALK_PORT }}"

Rename the following files  
*(this is a temporary step - to be automated later)*

- nextcloud-enterprise-redis-deployment.yaml => nextcloud-enterprise\*\*-database1\*\*-redis-deployment.yaml
- nextcloud-enterprise-nextcloud-deployment.yaml => nextcloud-enterprise-nextcloud2-deployment.yaml

```
mv templates/nextcloud-enterprise-redis-deployment.yaml templates/nextcloud-enterprise-database1-redis-deployment.yaml

mv templates/nextcloud-enterprise-nextcloud-deployment.yaml templates/nextcloud-enterprise-nextcloud2-deployment.yaml
```

Transfer the nextcloud-enterprise-helm-chart to the online and to the air-gapped server.

## Online server

#### Download images

Within the folder nextcloud-enterprise-helm-chart execute the following command to extract all required images for the deployment. 
These will need to be downloaded, validated and transferred to the air-gapped server.
This command will create a list of all required images.
Then it will download every required image from the docker repository and save them locally.

```
grep -rh 'image:' templates | \
sed -e 's/{{ .Values.NEXTCLOUD_IMAGE_ORG }}/nextcloud/g' \
    -e 's/{{ .Values.IMAGE_MIRROR_PREFIX }}//g' \
    -e 's/{{ .Values.ALPINE_IMAGE_ORG}}/library/g' | \
sed -n 's/.*image:[[:space:]]*"*\([^"]*\)"*/\1/p' | \
sort | uniq | \
while read IMAGE; do 
    podman pull $IMAGE && podman save -o $(echo $IMAGE | awk -F'[/:]' '{print $2}').tar $IMAGE
done
```

Now Transfer all files to the air-gapped server

## Air-gapped server

#### Load images into podman

On the air-gapped server, navigate to the folder with the image archives and load these into podman

```
for file in *.tar; do podman load -i "$file"; done
```

Configure the archives PVC or NFS mount as described in [our documentation](https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/values.yaml-ARCHIVES_PVC_NAME-for-local-archives).

#### Configure additional values

Navigate the folder nextcloud-enterprise-helm-chart.

Maintain the `values.yaml` files.  
At least, all !TODO values need to be changed.

Special settings need to be done for air-gapped:

- `APACHE_PORT`: use anything else besides 443; external reverse proxy is required that handles tls termination. You will point the reverse proxy at `http://ip.address.of.server:$APACHE_PORT`
- `NC_DOMAIN`: set this to your public domain of your external reverse proxy for which you have a valid public and globally trusted TLS certificate (not self-signed nor internal)
- `NEXTCLOUD_STARTUP_APPS`: remove anything besides "twofactor_totp"
- `AIRGAPPED: "yes"` => this will preconfigured Nextcloud accordingly

#### Build the yaml files

```
helm dependency build; 
helm template --dry-run --debug . --generate-name --values values.yaml > podman.yaml
```

#### Start the environment

podman kube play podman.yaml

#### Configure external reverse proxy

The Nextcloud server is now listening on the configured `APACHE_PORT`, for example, on `http://ip.address.of.server:$APACHE_PORT`.

It is assumed that you have a valid public and globally trusted TLS certificate (not self-signed nor internal) to make all sub-services work, for example, Collabora etc.

The external reverse proxy needs to terminate TLS traffic on your domain on port 443 and redirect it to the internal IP address and port from above.

Some examples of how to configure your reverse proxy are available [here](https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md#1-configure-the-reverse-proxy).

#### Cleanup

```
podman stop -a; podman rm -a; podman pod rm -a; podman volume prune -f
```
