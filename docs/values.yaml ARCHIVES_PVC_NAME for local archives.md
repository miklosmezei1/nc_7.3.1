# Enterprise-AIO - how to use the ARCHIVES_PVC_NAME variable

As an alternative to `ENTERPRISE_ARCHIVE_URL`, it is possible to use a dedicated PVC or NFS mount from which archives can be loaded and installed. This is especially useful in offline (airgapped) scenarios. It is possible to load Nextcloud Enterprise server archives and custom apps from the volume or mount.

Note: *This is work-in-progress. Feedback is very welcome!*

## Process steps

1. Preparation
2. Download archives
3. Prepare the PVC or NFS mount
3. Put the archives into the PVC or NFS mount
3. Put additional app archives into the PVC or NFS mount
3. Prepare Helm Charts
3. Example

## Details
--- PREVIEW ---

#### Preparation

Install Podman or Kubernetes on the server.

#### Download archives

Download the zip-archive from https://portal.nextcloud.com, that contains the enterprise archive like e.g. `nextcloud-31.0.5-enterprise.zip`.

#### Prepare the PVC or NFS mount

Depending on whether a PVC or NFS is used pick one of the following.

Prepare the PVC by using this `pvc.yaml` template for example:
(adjust the values accordingly and remember the name)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <your-pvc-name>
spec:
  # storageClassName: <your-storage-class> # Optional, if you want to use a specific storage class
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5G # 5 GB should probably be big enough for most archives
```

On Podman, run `podman kube play pvc.yaml`.
On Kubernetes, run `kubectl apply -f pvc.yaml`.

This approach is also applicable when NFS is used to mount volumes instead of PVCs.
The `ARCHIVES_PVC_NAME` value will be treated as a folder name in this case.
Additionally, the `NFS_PREFIX` will be prepended as usual.

The expected directory structure is shown below in the example.

#### Put the archives into the PVC or NFS mount

After the volume was created, mount it, put the archive in the root of it with the same name like e.g. `nextcloud-31.0.5-enterprise.zip`. Make sure to grant read access to the volume to everyone, e.g. to `755` via `chmod a+rx /path/to/mounted/volume`.

#### Put additional app archives into the PVC or NFS mount

Download app `*.tar.gz` archives from the Nextcloud app store or directly from GitHub.

At least the notify push app is always required for the notify push container to start correctly.
You can retrieve it from [here](https://apps.nextcloud.com/apps/notify_push/releases).

Create both subdirectories `nextcloud-31.0.5-enterprise/custom_apps` on the volume, ensure read
access and put your apps into it, e.g.
`nextcloud-31.0.5-enterprise/custom_apps/calendar-v5.0.0.tar.gz`
The first part of the subdirectory must always match the name of the main server archive without
the `.zip` suffix, e.g. `nextcloud-31.0.5-enterprise`.

All `*.tar.gz` archives inside `nextcloud-*.*.*-enterprise/custom_apps` will be installed or
updated each time the server is installed or updated.

#### Prepare Helm Charts

Now in enterprise-aio, set the following values:
- ENTERPRISE_ARCHIVE_URL => needs to have the same name of the archive that you used. In this example `nextcloud-31.0.5-enterprise.zip`
- ARCHIVES_PVC_NAME => needs to be the name of the PVC that you created above. In this example `<your-pvc-name>`.

Now, continue with the deployment like described in other articles.

#### Example

Values:
```yaml
ENTERPRISE_ARCHIVE_URL: nextcloud-31.0.5-enterprise.zip
ARCHIVES_PVC_NAME: custom-archives
NFS_PREFIX: /my/share # Only relevant if NFS is used
```

Depending on whether a PVC or NFS is used pick one of the following:

Folder structure inside the PVC `custom_archives`:
```
/nextcloud-31.0.5-enterprise/custom_apps/myapp-v5.0.0.tar.gz
/nextcloud-31.0.5-enterprise.zip (optional; will be downloaded automatically if not existing)
```

Folder structure on NFS:
```
/my/share/custom-archives/nextcloud-31.0.5-enterprise/custom_apps/myapp-v5.0.0.tar.gz
/my/share/custom-archives/nextcloud-31.0.5-enterprise.zip (optional; will be downloaded automatically if not existing)
```
