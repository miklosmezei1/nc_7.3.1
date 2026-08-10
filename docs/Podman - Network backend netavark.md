# Podman - Network backend `netavark`

The deprecated `cni` network backend of Podman is known to have problems with DNS resolution which
can lead to spurious outages of your Nextcloud instance.
Therefore, we strongly recommend installing the modern `netavark` backend.

## Process steps

1. Preparation
2. Ensure that Podman uses the `netavark` network backend

If not:

3. Install the backend
4. Configure Podman

## Details
--- PREVIEW ---

#### Preparation

Install Podman >= 4.0

#### Ensure that Podman uses the `netavark` network backend

First, check if the `netavark` backend is already installed and used by Podman.
Run the following command and check the output.

```
podman info | grep networkBackend:
```

The output should look like:

```
  networkBackend: netavark
```

#### Install the backend

If not, start by installing the netavark plugin for Podman.
The concrete steps depend on your linux distribution which is why we included a list below for the
most commonly used enterprise server distributions.
Please also make sure to update Podman to v4.0 or greater.

##### RHEL
```
dnf install netavark
```

##### Ubuntu/Debian
```
apt-get install netavark
```

##### SUSE
```
zypper install netavark
```

#### Configure Podman

Enable the backend by adding the following block to `/etc/containers/containers.conf` or
create the file if it does not exist.

```
[network]
network_backend = "netavark"
```

Afterwards, confirm that the backend is working correctly by running the `podman info` command from
above again.
