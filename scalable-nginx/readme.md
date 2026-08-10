# Scalable NGINX Server

This document contains steps to replace the default non-scalable apache container with a scalable nginx server.
By default it does not serve TLS and needs an ingress of reverse proxy for that.

If an ingress should be used follow all sections below.
If a custom external TLS reverse proxy is provisioned, the first section can be skipped.

## Set up ingress controller and certificate manager

The following setup has to be performed once per cluster.

The supported ingress controllers are NGINX Ingress Controller, and ingress-nginx.

The supported certificate manager is cert-manager.

Both, the ingress controller and the cert-manager instances, are available to the whole cluster and all deployments of the Nextcloud Enterprise Helm Chart.

### Install an ingress controller

You need *one* of NGINX Ingress Controller or ingress-nginx. In doubt use the first one, since ingress-nginx will become deprecated soon.

### NGINX Ingress Controller

```sh
# Assumption: Current directory is the repository root
cd scalable-nginx
helm install --namespace nginx-ingress --create-namespace -f nginx-ingress-values.yaml nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress
```

### ingress-nginx (deprecated)

```sh
# Assumption: Current directory is the repository root
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
cd scalable-nginx
helm install --namespace ingress-nginx --create-namespace -f ingress-nginx-values.yaml ingress-nginx ingress-nginx/ingress-nginx
```

The NGINX Ingress Controller chart is configured with a client body timeout of 3600 seconds by default.
This is done to ensure stable uploads from slow client connections.
Make sure to sync the value with `NEXTCLOUD_MAX_TIME` in `nextcloud-enterprise-helm-chart/values.yaml`


### Install cert-manager

```sh
# Assumption: Current directory is the repository root
helm repo add jetstack https://charts.jetstack.io
helm repo update
cd scalable-nginx
helm install --namespace cert-manager --create-namespace --set installCRDs=true cert-manager jetstack/cert-manager
```

### Install a Let's Encrypt cluster issuer for easy TLS
Optionally, Let's Encrypt is able to send automated warning notifications about expiring certificates that failed to be renewed.
An email address has to be supplied in [letsencrypt-cluster-issuer.yaml](letsencrypt-cluster-issuer.yaml) to enable notifications.
```sh
# Assumption: Current directory is the repository root
cd scalable-nginx
kubectl apply -f letsencrypt-cluster-issuer.yaml
```

### Wait a bit until everything is up and running ...

### *Optional:* Test TLS ingresses using a simple nginx deployment
```sh
# Assumption: Current directory is the repository root
cd scalable-nginx

# 1. Change the domains in test-ingress-deployment.yaml before applying
sed -i 's/my-test-domain.com/real-domain.com/' test-ingress-deployment.yaml

# 2. Configure an appropriate DNS record and point it to the load balancer ip of the ingress controller.
# For NGINX Ingress Controller
kubectl get svc -n nginx-ingress nginx-ingress-controller
# For ingress-nginx
kubectl get svc -n ingress-nginx ingress-nginx-controller

# 3. Apply the manifest
kubectl apply -f test-ingress-deployment.yaml

# Wait a bit until the certificate is provisionied ...
# Should show a nginx testing page containing "Welcome to nginx!"
curl https://real-domain.com

# 4. Cleanup
kubectl delete -f test-ingress-deployment.yaml
kubectl delete secrets nginx-test-ingress-tls
```

## Configure the Nextcloud Enterprise Helm Chart to use a scalable nginx instead of the default non-scalable Apache container

A nginx sub-chart is deployed to provision a scalable nginx.
Some entries in [values.yaml](../nextcloud-enterprise-helm-chart/values.yaml) have to be changed in order for that to work, see the documentation in the sections below.
Please refer to the [chart's readme](https://github.com/bitnami/charts/tree/main/bitnami/nginx/#parameters) for the documentation of all available values.

### Required changes
- Set `nginx.enabled` to `true`
- Set `APACHE_HOST` to `"nextcloud-enterprise-nginx"` (keep the `&APACHE_HOST` before the actual value)
- Set `APACHE_PORT` to `80`
- Ensure that `NAMESPACE` contains the `&NAMESPACE` anchor to link both values or adjust it manually for the sub-chart (`NAMESPACE` and `nginx.namespaceOverride` should match)

### For TLS via an ingress controller and cert-manager
- Set `INGRESS_ENABLED` to `"yes"`

### Optional: External reverse proxy instead of Ingress
If an ingress controller and cert-manager were not provisioned and an external reverse proxy should be used, the service type has to be changed to "LoadBalancer" in [values.yaml](../nextcloud-enterprise-helm-chart/values.yaml) to expose nginx:
```yaml
service:
  type: LoadBalancer
```
