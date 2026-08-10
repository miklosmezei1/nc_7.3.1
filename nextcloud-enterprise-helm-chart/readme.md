# Nextcloud Enterprise Helm Chart

This Helm Chart contains a scalable Nextcloud container with all necessary connectors that can be set up on your Kubernetes cluster. Additionally, a management container runs in parallel, that sets up the Nextcloud instance automatically, connects all other services, runs cronjobs and takes care of updates and Co. 

On top of that, non-scalable versions of services for a full Nextcloud Hub installation are bundled that the Nextcloud can connect to. If you need scalable versions of these, you need to set them up yourself and adjust values.yaml in order to point them at the correct address. 

## How to use this?
There are two ways, see below:

### Via git clone
First clone this repo with `git clone https://github.com/nextcloud-gmbh/enterprise-aio`. Then go into the directory with `cd enterprise-aio/nextcloud-enterprise-helm-chart` and check out the latest release that you can find here: https://github.com/nextcloud-gmbh/enterprise-aio/releases via e.g. `git checkout v1.0.0`. Then edit the values.yaml file in this folder and adjust at least all values marked with `# TODO!` ⚠️ **Warning**: Do not use the symbols `@` and `:` in your passwords. These symbols are used to build database connection strings. You will experience issues when using these symbols! (for further instructions regarding specific components, see the sections below)


Then run:

```
helm install enterprise-aio . -f values.yaml
```

And after a while, everything should be set up.

⚠️ If you run into issues with the VerticalPodAutoscaler, see [this note](#note-regarding-verticalpodautoscaler)

### Alternatively, via helm directly
First, go to https://github.com/settings/tokens and add a classic token with `read:packages` permission. Then, log in via helm to ghcr.io:
```
helm registry login ghcr.io
username: <your-github-username>
password: <the-classic-token>
```
Of course, you need to adjust `<your-github-username>` and `<the-classic-token>` accordingly.

Then, the values.yaml can be retrieved via `helm show values oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart --version <version-tag>`. Of course, the `<version-tag>` needs to be substituted, e.g. with `2.2.0`. You can retrieve versions from https://github.com/nextcloud-gmbh/enterprise-aio/pkgs/container/nextcloud-enterprise-helm-chart/versions?filters%5Bversion_type%5D=tagged. Make sure to edit the values.yaml file and adjust at least all values marked with `# TODO!` ⚠️ **Warning**: Do not use the symbols `@` and `:` in your passwords. These symbols are used to build database connection strings. You will experience issues when using these symbols! (for further instructions regarding specific components, see the sections below)

Afterwards, you should be able to install a specific release via
```
helm install enterprise-aio oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart --version <version-tag> -f values.yaml
```

And after a while, everything should be set up.

⚠️ If you run into issues with the VerticalPodAutoscaler, see [this note](#note-regarding-verticalpodautoscaler)

#### Note Regarding VerticalPodAutoscaler
There is a `VerticalPodAutoscaler` that is by default enabled. It is required so that the `HorizontalPodAutscaler` retrieves resource values and can do its work. Alternatively, you can configure the resources manually using the `*_RESOURCES` variables. However since VPA is not a default resource in Kubernetes, you need to install it first by following https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler#installation. It can be disabled by setting `VPA_ENABLED: "no"`.

### Scalable base Nextcloud installation

For a scalable base Nextcloud installation, you need to provide your own scalable redis, postgresql and nginx service and point at them by adjusting `APACHE_HOST`, `POSTGRES_HOST`, `REDIS_HOST`. See how to do this below.

The by default included non-scalable Apache container that also includes automatic TLS, can optionally be swapped with a scalable nginx. Extra steps are needed to enable automatic TLS via ingresses in this configuration. Install the [NGINX Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/) (or alternatively [ingress-nginx](https://kubernetes.github.io/ingress-nginx/deploy/#quick-start)) to expose the web server and [cert-manager](https://cert-manager.io/docs/installation/helm/) secure the web server with TLS. Please have a look at the [scalable nginx readme](../scalable-nginx) for detailed steps.

Instead of using the by default included non-scalable Postgresql container, you can optionally use your own Postgresql service (which might be scalable, e.g. by using [this chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql/) and setting up the database correctly by following [this documentation](https://docs.nextcloud.com/server/stable/admin_manual/configuration_database/linux_database_configuration.html#:~:text=template1%3D%23%20prompt%20will%20appear.-,now%20enter%20the%20following%20lines%20and%20confirm%20them%20with%20the%20enter%20key%3A,-CREATE%20USER%20username%20CREATEDB)) that can be pointed at by using `POSTGRES_HOST`. Additionally, the database to be used can be adjusted with `POSTGRES_DB` and the user with `POSTGRES_USER` by setting it to something else than `nextcloud` (`nextcloud` is reserved to only be used with the included database). The password for the user can be set with `DATABASE_PASSWORD`. Last but not least, with `DATABASE_TYPE`, you can adjust the database type in order to use this helm chart with an external mysql or mariadb database. Currently supported are the values `postgres` and `mysql` of which the latter is also reused with mariadb. Additionally, the port can be adjusted with `POSTGRES_PORT`. ⚠️ Please note that the bundled Postgres container only supports port 5432! Additionally the you can configure a root cert for postgresql tls connections by using `NEXTCLOUD_TRUSTED_CERTIFICATES.POSTGRES`. You should configure this before the initial installation of Nextcloud. Also note that the built-in database container does not support this.

The by default included non-scalable redis container, can optionally be exchanged with your own redis service (which might be scalable, e.g. by using [this chart](https://github.com/bitnami/charts/tree/main/bitnami/redis) or [this one](https://github.com/bitnami/charts/tree/main/bitnami/redis-cluster)) that can be pointed at by using `REDIS_HOST`. The port can be adjusted with `REDIS_PORT`. Additionally, the db index to be used can be adjusted with `REDIS_DB_INDEX`. The password can be set with `REDIS_PASSWORD` and the redis user can be set with `REDIS_USER`. Use `REDIS_MODE` to select `redis` or `rediscluster`. For cluster mode you can also provide `REDIS_HOST_2` to `REDIS_HOST_9` and corresponding `REDIS_PORT_2` to `REDIS_PORT_9`.
You can also configure a root cert for Redis tls connections by using `NEXTCLOUD_TRUSTED_CERTIFICATES.REDIS`. You should configure this before the initial installation of Nextcloud. 
⚠️ Please note that the bundled Redis container only supports `REDIS_DB_INDEX` 0, `REDIS_USER` being unset and `REDIS_PORT` set to `6379` or unset and the `REDIS_MODE` set to `redis`. Additionally, the rediscluster mode is currently only compatible with redis cluster v7 and redis cluster does not support `REDIS_DB_INDEX`. Instead you can set `REDIS_PREFIX`. 
⚠️ Also, the whiteboard app currently does not support redis cluster and not `REDIS_PREFIX` and it currently does not support TLS-connections to Redis.

### Scalable full Nextcloud Hub installation

For a complete scalable Nextcloud Hub installation, you need to additionally (on top of the scalable base Nextcloud installation) provide your own collabora, talk and elasticsearch service and point at them by adjusting, `COLLABORA_HOST` (or alternatively `ONLYOFFICE_HOST`), `TALK_HOST` and `FULLTEXTSEARCH_HOST`.

For collabora, see [this documentation](https://sdk.collaboraonline.com/docs/installation/Kubernetes.html) how to set up a scalable variant on your cluster. The chosen domain then needs to be added to Nextcloud via `COLLABORA_HOST`. Also make sure to set `COLLABORA_ENABLED: "yes"` so that it gets automatically enabled and configured in Nextcloud.

Alternatively to Collabora, Onlyoffice can be set up in a scalable variant by following [this documentation](https://www.onlyoffice.com/blog/2021/11/deploy-onlyoffice-docs-into-kubernetes-or-openshift-cluster-using-helm). The chosen domain then needs to be added to Nextcloud via `ONLYOFFICE_HOST` and the configured JWT-token via `ONLYOFFICE_SECRET`. Also make sure to set `ONLYOFFICE_ENABLED: "yes"` so that it gets automatically enabled and configured in Nextcloud.

For Talk, see [this documentation](https://portal.nextcloud.com/article/Nextcloud-Talk/High-Performance-Backend/Installation/Helmcharts) how to set up a scalable variant on your cluster. The chosen domain then needs to be added to Nextcloud via `TALK_HOST`. Similarly, the path to the signaling server in that domain needs to be set via `TALK_HPB_PATH` (including the leading `/`). Also make sure to set `TALK_ENABLED: "yes"` so that it gets automatically enabled and configured in Nextcloud. Additionally, the secrets can be configured via `SIGNALING_SECRET` and `TALK_INTERNAL_SECRET`.

For Elasticsearch, see [this documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-stack-helm-chart.html) how to set up a scalable variant on your cluster. The chosen internal domain then needs to be added to Nextcloud via `FULLTEXTSEARCH_HOST`. Also make sure to set `FULLTEXTSEARCH_ENABLED: "yes"` so that it gets automatically enabled and configured in Nextcloud. Additionally, the secret can be configured via `FULLTEXTSEARCH_PASSWORD`. On top of that, the port can be configured with `FULLTEXTSEARCH_PORT`, the protocol can be configured with `FULLTEXTSEARCH_PROTOCOL`, the user can be configured with `FULLTEXTSEARCH_USER` and the index can be configured with `FULLTEXTSEARCH_INDEX`. ⚠️ Please note that the built-in fulltextseach deployment only supports the default port `9200`, the default protocol `http` and the default user `FULLTEXTSEARCH_USER`.

## How to update?
Since the values of this helm chart may change in the future, it is highly recommended to strictly follow the following procedure whenever you want to upgrade it.
1. Optional but recommended: first, stop all running pods by running `kubectl -n <namespace> scale deployment --replicas=0 <deployment>`, one for each deployment and wait for them to stop. This ensures a consistent state for the backup. Alternatively, you can enable the maintenance mode via `kubectl exec deployment/nextcloud-enterprise-nextcloud-management -- php occ maintenance:mode --on` (⚠️ This command should not be used in case of a major upgrade of this helm chart. In that case you should use the `kubectl scale` command).
1. Back up all PVCs that got created by the Helm chart (or the NFS mounts) and back up the `values.yaml` file (and also back up your database and Elasticsearch if you are using an external one). Also write down the git tag that you are currently using so that you can revert to that if needed later on.
1. Check out the latest release that you can find here: https://github.com/nextcloud-gmbh/enterprise-aio/releases via e.g. `git checkout v1.0.0` (do not skip any major version so upgrade from one major to the next; increasing the major version means you need to adjust some values or for example the bundled Nextcloud major version was increased). Alternatively, you might get the latest values via `helm show values oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart --version <version-tag>`. Of course, the `<version-tag>` needs to be substituted, e.g. with `2.2.0`. You can retrieve versions from https://github.com/nextcloud-gmbh/enterprise-aio/pkgs/container/nextcloud-enterprise-helm-chart/versions?filters%5Bversion_type%5D=tagged. (do not skip any major version so upgrade from one major to the next; increasing the major version means you need to adjust some values or for example the bundled Nextcloud major version was increased)
1. Make sure to update the `ENTERPRISE_ARCHIVE_URL` variable in values.yaml if you want to upgrade Nextcloud which should be done regularly. (Easiest is to just use the URL that comes with the `values.yaml` file of the checked out git tag) 
1. Make sure to update the `nginx.image.tag` variable in values.yaml if you want to upgrade the nginx subchart which should be done regularly. (Easiest is to just use the value that comes with the `values.yaml` file of the checked out git tag). Additionally, make sure that `nginx.image.repository` is set to `nextcloud-releases/nce-nginx` and `nginx.image.registry` is set to `ghcr.io` as shown in the values file.
1. If you do a major jump, compare the new values.yaml file with the one that you currently have locally. Look for variables that changed or got added. You can use the diff command to compare them. Also, ensure that all pods got stopped via `kubectl scale` - see the first step of this guide.
1. Optional but recommended: [validate your values.yaml file](#validation-of-valuesyaml-file)
1. At last step, simply run `helm upgrade enterprise-aio . -f values.yaml` to update to the new version. Alternatively run `helm upgrade enterprise-aio oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart --version <version-tag> -f values.yaml`
1. If you used the `kubectl -n <namespace> scale deployment --replicas=0 <deployment>` in the first step, you now need to run `kubectl -n <namespace> scale deployment --replicas=1 <deployment>` to scale those pods back up that were not already restarted from the helm upgrade command.
1. If something should go wrong, feel free to restore the backup of the volumes and values.yaml file and also go back to the git tag that you have checked out before upgrading. Then the same command like above should make it running again.
