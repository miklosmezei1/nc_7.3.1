# Setting up the chart for development

We are going to set up a E-AIO instance on an Ubuntu VM inside a Tailnet via Tailscale.

## Create VM

Set up a Ubuntu server LTS VM. 

As a hypervisor we recommend to use [VirtualBox](https://www.virtualbox.org/wiki/Downloads) on Windows, and [Lima](https://lima-vm.io) on Linux and Macos. Other hypervisors might work, too, if you know how to configure TTY/SSH access and port forwarding.

⚠️ Please note that WSL on Windows is not supported as Hypervisor.

The default E-AIO configuration will consume at least 18GB of storage on the VM. Recommended is a VM with 50 GB storage. 

Also, 8 GB RAM and 4 CPUs are recommended.

### Linux and Macos: Lima

#### Intel systems

On a system with an Intel CPU (aka `AMD64`, `x86_64`) run this command in your terminal to create and start a VM:

```sh
limactl start --name default --memory=8 --mount-writable
```


#### ARM systems

On a system with an ARM CPU (aka `ARM64`, e.g. Macs with an M*-chip) you will need to make use of an emulation layer, because not all images are available for that hardware platform, yet.

**On a Mac** you can use Lima's built-in support for Rosetta:

```sh
limactl start --name default --memory=8 --mount-writable --vm-type=vz --rosetta --network=vzNAT
```

(If you don't yet have Rosetta installed, the previous command might trigger its installation. If an error occurs instead, try to install Rosetta manually by executing this command in your terminal: `softwareupdate --install-rosetta --agree-to-license`.)

**On a Linux system** you need to use the slower qemu mode:

```sh
limactl start --name default --memory=8 --mount-writable --vm-type=qemu --arch=x86_64 --plain
```

In all these setups run this command to get a shell inside the VM: `limactl shell default`.


### Windows: VirtualBox

On Windows we recommend to set up the VM with VirtualBox, because on it Lima is not easily installable and also is officially considered untested.

Install it from https://www.virtualbox.org/wiki/Downloads and create a new virtual machine from the GUI. If you'd like to follow a tutorial have a look at https://ubuntu.com/tutorials/how-to-run-ubuntu-desktop-on-a-virtual-machine-using-virtualbox#1-overview (but download the Ubuntu Server image, not the Ubuntu Desktop image).

Please make sure to choose a "NAT" network and configure a port forwarding of port 22 on 127.0.0.1 to your VMs port 22, so you will be able to login into the machine with SSH and avoid potential issues with copy&paste through the GUI's console.

Here's how the network configuration should look like:

<img width="1039" height="748" alt="Image" src="https://github.com/user-attachments/assets/c70e2032-c7d9-494b-a90c-f3932a443e2a" />

When the VM is running you should be able to run `ssh <your-ubuntu-user>@localhost` to log into it (`<your-ubuntu-user>` should be adjusted according to your setup).

## Set up Tailscale

If you did not already, create a Tailscale account: https://login.tailscale.com/login
Head to: https://login.tailscale.com/admin/dns

Make sure to enable MagicDNS And HTTPS Certificates:
<img width="700" height="373" alt="Bildschirmfoto vom 2025-10-01 17-09-35" src="https://github.com/user-attachments/assets/cf5c8f81-ed4d-4219-a1d7-894b84044cd0" />

Also go to https://login.tailscale.com/admin/acls/visual/node-attributes/add and add a tag that allows to use Tailscale Funnel:
  <img width="1499" height="1207" alt="Image" src="https://github.com/user-attachments/assets/05cf24e8-28e5-4fcb-aebd-5d62c49fcb47" />

### Add your server to your Tailnet.

**Register your server:**
- Head to: https://login.tailscale.com/admin/machines/new-linux
- Click on "Generate install script"
- Execute the copied script on your server.

### Copy the Tailscale domain of your server VM

Head to: https://login.tailscale.com/admin/machines
Click on the address next of your server machine.

<img width="289" height="217" alt="image" src="https://github.com/user-attachments/assets/e78c92db-22f1-44f8-9bfb-31cb12024b78" />

The domain is the second entry in this example.

## Set up K3s

In your VM now install K3s, a lightweight Kubernetes distribution suitable for local setups. (Hint: if at this point network connections suddenly do not work anymore, you might need to temporarily turn tailscale off and turn it back ont later.)

```sh
curl -sfL -o install.sh https://get.k3s.io
curl -sfLO https://raw.githubusercontent.com/k3s-io/k3s/refs/heads/main/install.sh.sha256sum
if shasum -a 256 -c install.sh.sha256sum; then
    INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb" sh ./install.sh
fi
```

```sh
# Check the k3s status
# Should answer “Ready” in the Status
sudo k3s kubectl get node
```

```sh
sudo chgrp $(id -g) /etc/rancher/k3s/k3s.yaml
sudo chmod g+r /etc/rancher/k3s/k3s.yaml
mkdir ~/.kube
sudo install -o "$(id -u)" -m 400 /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

## Install Helm

```sh
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Set up Longhorn (PVC storage provider)

Ref <https://longhorn.io/docs/1.10.0/deploy/install/install-with-helm/>

Create `longhorn-values.yaml`:

```yaml
# longhorn-values.yaml
persistence:
  defaultClass: false
  defaultClassReplicaCount: 1
```

```sh
# install longhorn
sudo apt install nfs-common # Required for RWX
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.10.0 -f longhorn-values.yaml
```

```sh
# Check progress
kubectl -n longhorn-system get pod
```

<!--
### Optional: Expose the longhorn UI (for debugging)

The Longhorn frontend should never(!) be exposed on a public IP.
It does not have password protection.

```sh
KUBE_EDITOR="nano" kubectl edit -n longhorn-system svc longhorn-frontend

# change the serviceType to LoadBalancer

kubectl get svc -n longhorn-system

# -> look for the frontend service, check the port -> you should be able to access the longhorn web UI in your browser on the following: <k3s IP:longhorn-frontendPort>
```
-->

## Download the E-AIO Helm chart

Set up the GitHub CLI and log in to your GitHub account on the server: https://cli.github.com/
Clone the enterprise-aio repository:

```sh
gh repo clone nextcloud-gmbh/enterprise-aio
```

## Configure `values.yaml`

We are going to configure the Helm chart.

```sh
cd enterprise-aio/nextcloud-enterprise-helm-chart
nano values.yaml
```

Here is a list of values that need to be adjusted:
- `*_PASSWORD` and `*_SECRET`: Set those to secure passwords.
- `NC_DOMAIN: <your-tailscale-domain>` (just the hostname, without schema prefix or trailing slash)
- `*_ENABLED`: Set to `"yes"` to enable the services you would like to test.
- `STORAGE_CLASS: longhorn`
- `STORAGE_CLASS_DATA: longhorn`
- `NAMESPACE: &NAMESPACE eaio1`
- `VPA_ENABLED: "no"`
- `APACHE_HOST: &APACHE_HOST nextcloud-enterprise-nginx`
- `nginx.enabled: true`
- `nginx.service.type: LoadBalancer`

## Install the Helm chart

```sh
# Go into the directory if not already done
# cd enterprise-aio/nextcloud-enterprise-helm-chart

# Download install Nginx chart
helm dependency build

# Install the E-AIO chart
helm install eaio1 . -f values.yaml
```

```sh
# Check status of all Pods
kubectl get pod -w -n eaio1

# Watch install logs
kubectl logs -f deploy/nextcloud-enterprise-nextcloud-management -n eaio1
```

```sh
# Extract service port for the nextcloud-enterprise-nginx (LoadBalancer). One example output is '80:31704/TCP', then the port you need to use is 31704
kubectl get svc -n eaio1 | grep nginx

```

## Expose the Nginx load balancer to the public

```sh
# Insert the load balancer port that you retrieved above here. E.g. 31704
sudo tailscale funnel --bg 31704
```

## Test the Nextcloud webinterface

Go to the configured domain in your browser.
You should be able to see a login form where you can log in as `admin` using the password you
configured earlier in the `values.yaml` file (`NEXTCLOUD_PASSWORD`).

## Turn off Tailscale after successful testing
```sh
sudo tailscale funnel reset
```
