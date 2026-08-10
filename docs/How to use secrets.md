# Enterprise-AIO - How to use secrets

The Enterprise-AIO Helm chart can be configured to use Kubernetes or Podman secrets.

## Process steps

1. Enable `USE_SECRETS` in `values.yaml`
1. Create all secrets
1. Examples

## Details
--- PREVIEW ---

### Enable `USE_SECRETS` in `values.yaml`

Set `USE_SECRETS` to `"yes"` (with quotes) in `values.yaml` to enable the feature.

### Create all secrets

You can run the following script inside the directory of the Helm chart to get a list of all variables you need to configure in `values.yaml`:
```
grep -RE '^                  key:' templates | grep -Eo '\{\{.*\}\}' | sed -E 's|\{\{ \.Values\.||;s| \}\}||;' | sort | uniq
```
The value that you chose for each variable is the name of the secret.
Each secret is expected to contain a single key with the same name as the secret itself.

To create the secrets you can chose one of the following methods.

#### Via `kubectl` on Kubernetes

On Kubernetes you can run the following command:
```
kubectl create secret generic -n <namespace> --from-literal=<secret-name>=<raw-data> <secret-name>
```
The data *does not* need to be encoded beforehand in this case.

#### Via a YAML template on Kubernetes and Podman

To create a secret you can adapt the following YAML template:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <secret-name>
type: Opaque
data:
  <secret-name>: <base64-encoded-data>
```

Make sure to replace `<secret-name>` with an appropriate name.
The data needs to be encoded using base64 beforehand.

You can apply the secret template using one of the following commands:
- Kubernetes: `kubectl apply -n <namespace> -f secret.yaml`
- Podman: `podman kube play secret.yaml`

### Examples

#### `values.yaml`

```yaml
USE_SECRETS: "yes"
NEXTCLOUD_PASSWORD: nc-password
```

#### Via `kubectl` on Kubernetes

```
kubectl create secret generic --from-literal=nc-password=my-secret-password nc-password
```

#### Via a YAML template on Kubernetes and Podman

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: nc-password
type: Opaque
data:
  nc-password: bXktc2VjcmV0LXBhc3N3b3Jk
```
