# Nextcloud Enterprise deployment for Kubernetes, OpenShift and Podman
This repository contains the official Nextcloud Enterprise deployment for Kubernetes, OpenShift and Podman.

Main part of it is the Nextcloud Enterprise Helm Chart that contains a scalable Nextcloud container and a management container with all necessary connectors that can be set up on your Kubernetes or OpenShift cluster or Podman installation.

## FAQ

### How to deploy?

For further instructions and hints, go into the [nextcloud-enterprise-helm-chart subfolder](./nextcloud-enterprise-helm-chart/).

#### What are requirements for the Storage Providers of the Kubernetes or OpenShift Cluster?
The Helm chart needs a storage class that provides ReadWriteMany access to PVCs.

#### Note regarding Microsoft Azure Kubernetes Service (AKS)
If you use this Helm Chart on Microsoft Azure via their Azure Kubernetes Service, and if you use their [Azure Files storage backend](https://learn.microsoft.com/en-us/azure/aks/azure-csi-files-storage-provision), make sure to use nfs as protocol (`volumeAttributes.protocol: nfs`) as otherwise normal Linux permissions are not working and this helm chart will fail during the initial installation.

### Is there a deployment with Podman?

[Yes](./docs/Podman.md), since Podman is able to read and install Kubernetes files.

### Can Enterprise-AIO be operated in an offline (airgapped) scenario?

Yes. A how-to is [available here](./docs/Airgapped installation.md).
Installing the chart on airgapped Podman is [shown here](./docs/Podman%20-%20Offline%20(airgapped).md).

### Note regarding deployments that do not receive an IP from an external loadbalancer, a virtual loadbalancer may be required.
If your environment is configured in a way that does not assign an IP to service type **LoadBalancer** or if you are unable to front the cluster with a software loadbalancer like HAProxy, a virtual loadbalancer like Metallb may be required to be deployed to your cluster. [more information here](./docs/Metallb.md)

### Is there a migration path from ownCloud to Enterprise-AIO?

[Yes](./docs/Migration%20from%20ownCloud.md)

### How to give customers access to this repo?

Simply [post a comment in this talk chat](https://cloud.nextcloud.com/call/7278172873) to give the customer access to this repo. The customer needs to provide the Github usernames that should be added. We will give them read access to this repo, as well as adding them to this list: [click here](https://cloud.nextcloud.com/apps/tables/#/table/577)
