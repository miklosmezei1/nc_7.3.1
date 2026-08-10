# Enterprise-AIO with Podman

The Enterprise-AIO can be operated with Podman with some minor adjustments.
**Warning:** Podman does not support horizontal scaling. Horizontal scaling can currently only be achieved by using E-AIO with K8s.
**Note:** *This is work-in-progress*

## Process steps

1. Preparation
1. Ensure that Podman uses the `netavark` network backend
1. Prepare Helm Charts
1. Maintain values.yaml
1. Build the podman yaml
1. Start the environment

## Details
--- PREVIEW ---

#### Preparation

Install Podman >= 4.0 (required for the `netavark` network backend)

Install [Helm](https://helm.sh/docs/intro/install/)

#### Ensure that Podman uses the `netavark` network backend

The process is documented [here](./Podman---Network-backend-netavark).

#### Prepare Helm Charts
Download the enterprise-helm-chart archive file from the GitHub repository (contact your Sales Engineer) and unpack.

Navigate into the folder nextcloud-enterprise-helm-chart

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

#### Maintain values.yaml

Navigate the folder nextcloud-enterprise-helm-chart

Maintain the values.yaml files.  
At least, all !TODO values need to be changed.

#### Build the podman yaml

```
helm dependency build; 
helm template --dry-run --debug . --generate-name --values values.yaml > podman.yaml
```

#### Start the environment

podman kube play podman.yaml

### Cleanup

podman stop -a; podman rm -a; podman pod rm -a; podman volume prune -f
