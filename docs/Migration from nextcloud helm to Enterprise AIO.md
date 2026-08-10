# Migration from nextcloud/helm to Enterprise-AIO

This guide covers migrating from the community [nextcloud/helm](https://github.com/nextcloud/helm) chart to Nextcloud Enterprise-AIO.

--- PREVIEW ---

Note: *This is work-in-progress. Feedback is very welcome!*

## Table of Contents

1. [Overview and key differences](#1-overview-and-key-differences)
2. [Prerequisites](#2-prerequisites)
3. [Phase 1 — Prepare and back up your existing deployment](#3-phase-1--prepare-and-back-up-your-existing-deployment)
4. [Phase 2 — Migrate the database to PostgreSQL (optional)](#4-phase-2--migrate-the-database-to-postgresql-optional)
5. [Phase 3 — Export user data from the existing deployment](#5-phase-3--export-user-data-from-the-existing-deployment)
6. [Phase 4 — Configure the Enterprise-AIO values.yaml](#6-phase-4--configure-the-enterprise-aio-valuesyaml)
7. [Phase 5 — Install Enterprise-AIO and restore data](#7-phase-5--install-enterprise-aio-and-restore-data)
8. [Phase 6 — Post-migration validation](#8-phase-6--post-migration-validation)
9. [Values.yaml mapping reference](#9-valuesyaml-mapping-reference)
10. [Optional components configuration](#10-optional-components-configuration)
11. [Rollback procedure](#11-rollback-procedure)

---

## 1. Overview and key differences

Before starting the migration, it is important to understand the fundamental architectural differences between the two charts.

### Architecture

| Aspect | nextcloud/helm | Enterprise-AIO |
|---|---|---|
| Main Nextcloud container | Community image (`library/nextcloud`) | Enterprise image (`.zip` archive from `ENTERPRISE_ARCHIVE_URL`) |
| Management / automation | Not included | Dedicated management container that auto-configures everything |
| Web server | Apache (built-in) or nginx sidecar | Apache with integrated TLS (default) or scalable nginx sub-chart |
| Database | Internal MariaDB/PostgreSQL or external | Internal PostgreSQL or external (PostgreSQL or MySQL/MariaDB) |
| Redis | Bitnami Redis sub-chart or external | Internal Redis deployment or external |
| Collabora | Via `collabora` sub-chart | Bundled non-scalable deployment (or external) |
| Talk / High-Performance Backend | Not included | Bundled non-scalable deployment (or external) |
| ClamAV | Not included | Bundled deployment (optional) |
| Full-text search | Not included | Bundled Elasticsearch deployment (optional) |
| OnlyOffice | Not included | Bundled deployment (optional) |
| Imaginary | Via `imaginary` sub-chart | Bundled deployment (optional) |
| Notify Push | Not included | Bundled and auto-configured |
| Autoscaling | Optional HPA | HPA + VPA enabled by default |
| Cron jobs | Separate cron job or sidecar | Managed by the management container |
| Updates | Manual `helm upgrade` | Management container handles Nextcloud upgrades |
| Configuration format | Nested YAML | Flat key-value pairs |

### Management container

The most significant architectural difference is the **management container** in Enterprise-AIO. It:

- Automatically configures all integration points (database, Redis, office suites, Talk, etc.)
- Runs cron jobs
- Performs automated Nextcloud upgrades when you update `ENTERPRISE_ARCHIVE_URL`
- Manages app installations and updates

This means that unlike in the community chart, **you do not manually configure `config.php` entries** for most services — the management container does it for you based on your `values.yaml`.

### Values.yaml format

The community chart uses standard nested Helm YAML, whereas Enterprise-AIO uses a flat key-value structure directly under the document root. For example:

**nextcloud/helm:**
```yaml
nextcloud:
  host: cloud.example.com
  username: admin
  password: changeme
externalDatabase:
  enabled: true
  type: postgresql
  host: my-postgres
  user: nextcloud
  password: secret
  database: nextcloud
```

**Enterprise-AIO:**
```yaml
NC_DOMAIN: cloud.example.com
NEXTCLOUD_PASSWORD: changeme
POSTGRES_HOST: my-postgres
POSTGRES_USER: nextcloud
DATABASE_PASSWORD: secret
POSTGRES_DB: nextcloud_database
```

---

## 2. Prerequisites

Before starting the migration:

- [ ] You have `kubectl` configured with access to your cluster
- [ ] You have `helm` v3 installed
- [ ] You have read the [Enterprise-AIO Helm chart README](https://github.com/nextcloud-gmbh/enterprise-aio/blob/main/nextcloud-enterprise-helm-chart/readme.md)
- [ ] You have access to the repository
- [ ] You have a Nextcloud Enterprise subscription and have received your `ENTERPRISE_ARCHIVE_URL` from Nextcloud GmbH
- [ ] You have sufficient disk space to hold a full backup of all PVCs
- [ ] You understand that Enterprise-AIO requires a storage class that provides **ReadWriteMany (RWX)** access — check that your cluster has one available

> ⚠️ **Warning**: Do not use the symbols `@` and `:` in any passwords. These are used to build database connection strings and will cause failures.

---

## 3. Phase 1 — Prepare and back up your existing deployment

### 3.1 Enable maintenance mode

Enable Nextcloud maintenance mode before taking any backup to ensure data consistency:

```sh
# Replace <namespace> and <deployment-name> with your values
kubectl exec -n <namespace> deployment/<nextcloud-deployment-name> -- php occ maintenance:mode --on
```

### 3.2 Scale down all pods

```sh
# List all deployments in your namespace
kubectl get deployments -n <namespace>

# Scale down each one
kubectl scale deployment -n <namespace> <deployment-name> --replicas=0
```

If you are using the Bitnami MariaDB or PostgreSQL sub-charts, also scale those down after noting the pod names:

```sh
kubectl scale statefulset -n <namespace> <statefulset-name> --replicas=0
```

### 3.3 Back up all PVCs

Identify all PVCs used by your deployment:

```sh
kubectl get pvc -n <namespace>
```

For each PVC, create a backup pod and copy the data to your local machine. The following is a template for copying data from a PVC:

```sh
# Start a temporary pod to access the PVC
kubectl run backup-pod -n <namespace> --image=alpine --overrides='
{
  "spec": {
    "containers": [{
      "name": "backup-pod",
      "image": "alpine",
      "command": ["sleep", "3600"],
      "volumeMounts": [{"mountPath": "/data", "name": "vol"}]
    }],
    "volumes": [{"name": "vol", "persistentVolumeClaim": {"claimName": "<pvc-name>"}}]
  }
}' --restart=Never

# Copy data locally
kubectl cp -n <namespace> backup-pod:/data ./backup-<pvc-name>

# Clean up
kubectl delete pod -n <namespace> backup-pod
```

Repeat for every PVC. The most important ones are:
- The **Nextcloud data PVC** (contains all user files)
- The **database PVC** (if using a bundled database)

### 3.4 Back up your existing values.yaml

```sh
cp values.yaml values.yaml.backup-$(date +%Y%m%d)
```

### 3.5 Export the Nextcloud configuration

Connect to your running Nextcloud pod and export the current configuration:

```sh
kubectl exec -n <namespace> deployment/<nextcloud-deployment-name> -- php occ config:list --private > nextcloud-config-backup.json
```

Write down or note the following values from your existing deployment for use later:
- Nextcloud admin username
- Domain / trusted domain
- SMTP settings
- Any custom `config.php` values (S3, trusted proxies, etc.)
- All app names that are currently installed and enabled

---

## 4. Phase 2 — Migrate the database to PostgreSQL (optional)

> **This entire phase is optional.** Enterprise-AIO supports connecting to an external database server of your choice by setting `POSTGRES_HOST` to an external host and `DATABASE_TYPE` to `postgres` or `mysql` in `values.yaml`. The external database must be provisioned and managed entirely outside of Enterprise-AIO — it is not deployed or managed by this chart. If you choose to bring your own external database (e.g. keep your existing MariaDB/MySQL), skip this phase entirely and configure the connection in [Phase 4](#6-phase-4--configure-the-enterprise-aio-valuesyaml).

If you want to use the **built-in PostgreSQL** database that Enterprise-AIO provides, continue with this phase. The built-in database only supports PostgreSQL, so if your current deployment uses MariaDB or MySQL you must convert before migrating. If you are already using PostgreSQL you can skip to [section 4.3](#43-export-the-database).

### 4.1 Convert from MariaDB/MySQL to PostgreSQL (if needed)

If your community chart deployment uses MariaDB or MySQL, you need to first convert the Nextcloud database to PostgreSQL. Scale your existing deployment back up temporarily for this step:

```sh
# Scale back up the Nextcloud pod (keep the web server scaled down)
kubectl scale deployment -n <namespace> <nextcloud-deployment-name> --replicas=1
```

You will need a reachable PostgreSQL server. You can temporarily deploy one in-cluster:

```sh
helm install temp-postgres bitnami/postgresql \
  --set auth.username=ncmigrate \
  --set auth.password=temporarypassword \
  --set auth.database=nextcloud_migration \
  -n <namespace>
```

Then run the Nextcloud database conversion command inside the Nextcloud container:

```sh
kubectl exec -n <namespace> deployment/<nextcloud-deployment-name> -- \
  php occ db:convert-type \
    --all-apps \
    --password "temporarypassword" \
    pgsql ncmigrate <postgres-service-hostname> nextcloud_migration
```

Wait for the conversion to complete (this may take a long time for large databases).

### 4.2 Run required PostgreSQL maintenance steps

After conversion, run the recommended PostgreSQL optimizations:

```sh
kubectl exec -n <namespace> deployment/<nextcloud-deployment-name> -- \
  php occ db:add-missing-indices

kubectl exec -n <namespace> deployment/<nextcloud-deployment-name> -- \
  php occ db:add-missing-primary-keys

kubectl exec -n <namespace> deployment/<nextcloud-deployment-name> -- \
  php occ db:add-missing-columns
```

### 4.3 Export the database

Scale the Nextcloud pod back down, then take a PostgreSQL dump:

```sh
kubectl scale deployment -n <namespace> <nextcloud-deployment-name> --replicas=0

# Execute pg_dump inside the PostgreSQL pod or statefulset
kubectl exec -n <namespace> <postgres-pod-name> -- \
  pg_dump -U <db-user> <db-name> > database-dump.sql
```

### 4.4 Modify the database dump for Enterprise-AIO

Enterprise-AIO stores Nextcloud user data under `/mnt/ncdata/`. Your existing deployment likely uses a different path. You must update the storage paths in the SQL dump before importing it.

Open `database-dump.sql` and find references to the `oc_storages` table. Every `local::` path entry needs to point to `/mnt/ncdata/`:

```sh
# Example: replace your old data path with the Enterprise-AIO data path
sed -i 's|local::/var/www/html/data/|local::/mnt/ncdata/|g' database-dump.sql
# Adjust the old path above to match whatever path your current deployment uses
```

> ⚠️ The exact old path depends on your `nextcloud.datadir` setting in the community chart. Common values are `/var/www/html/data` (default) or a custom path if you used `nextcloud.datadir`.

---

## 5. Phase 3 — Export user data from the existing deployment

### 5.1 Identify the data PVC

In the community chart, user data lives in the PVC bound to the `nextcloud-data` volume (the path is `nextcloud.datadir`, defaulting to `/var/www/html/data`).

```sh
# Find the PVC name
kubectl get pvc -n <namespace> | grep nextcloud
```

### 5.2 Copy the data directory

If you have not already backed this up in Phase 1, do it now. The data directory contains:
- User files (in per-user subdirectories)
- `appdata_<instanceid>/` folder (thumbnails, previews, etc.)

```sh
kubectl run data-backup -n <namespace> --image=alpine --overrides='
{
  "spec": {
    "containers": [{
      "name": "data-backup",
      "image": "alpine",
      "command": ["sleep", "3600"],
      "volumeMounts": [{"mountPath": "/data", "name": "vol"}]
    }],
    "volumes": [{"name": "vol", "persistentVolumeClaim": {"claimName": "<your-nextcloud-data-pvc>"}}]
  }
}' --restart=Never

kubectl cp -n <namespace> data-backup:/data ./nextcloud-data-backup
kubectl delete pod -n <namespace> data-backup
```

---

## 6. Phase 4 — Configure the Enterprise-AIO values.yaml

### 6.1 Obtain the Enterprise-AIO Helm chart

**Option A — via git clone:**
```sh
git clone https://github.com/nextcloud-gmbh/enterprise-aio
cd enterprise-aio/nextcloud-enterprise-helm-chart
git checkout <latest-release-tag>   # See https://github.com/nextcloud-gmbh/enterprise-aio/releases
```

**Option B — via Helm OCI:**
```sh
helm registry login ghcr.io
# username: <your-github-username>
# password: <classic-token-with-read:packages-permission>

helm show values oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart \
  --version <version-tag> > values.yaml
```

### 6.2 Fill in mandatory values

Edit `values.yaml` and set **all** fields marked with `# TODO!`:

```yaml
DATABASE_PASSWORD: "your-strong-database-password"
FULLTEXTSEARCH_PASSWORD: "strong-password"       # Only needed if FULLTEXTSEARCH_ENABLED: "yes"
IMAGINARY_SECRET: "strong-password"              # Only needed if IMAGINARY_ENABLED: "yes"
NC_DOMAIN: "cloud.example.com"                   # Your Nextcloud domain
NEXTCLOUD_PASSWORD: "your-admin-password"        # Admin user initial password
ONLYOFFICE_SECRET: "strong-password"             # Only needed if ONLYOFFICE_ENABLED: "yes"
RECORDING_SECRET: "strong-password"              # Only needed if TALK_RECORDING_ENABLED: "yes"
REDIS_PASSWORD: "strong-password"
SIGNALING_SECRET: "strong-password"              # Only needed if TALK_ENABLED: "yes"
TALK_INTERNAL_SECRET: "strong-password"          # Only needed if TALK_ENABLED: "yes"
TIMEZONE: "Europe/Berlin"                        # Your timezone
TURN_SECRET: "strong-password"                   # Only needed if TALK_ENABLED: "yes"
WHITEBOARD_SECRET: "strong-password"             # Only needed if WHITEBOARD_ENABLED: "yes"
ENTERPRISE_ARCHIVE_URL: "https://download.nextcloud.com/.customers/server/..."  # Your enterprise archive URL
```

### 6.3 Configure storage class

Enterprise-AIO requires a storage class that provides **ReadWriteMany (RWX)** access. Set this based on your cluster's available storage classes:

```sh
kubectl get storageclasses
```

```yaml
STORAGE_CLASS: "your-rwx-storage-class"
```

If you want to use a different (potentially slower/cheaper) storage class for user data:

```yaml
STORAGE_CLASS_DATA: "your-rwx-storage-class-for-data"
```

> ⚠️ Only set `STORAGE_CLASS_DATA` for new installations, not for migrations where you are reusing existing PVCs.

### 6.4 Configure the namespace

```yaml
NAMESPACE: &NAMESPACE your-namespace
```

If you are installing into a pre-existing namespace:

```yaml
NAMESPACE_DISABLED: "yes"
```

### 6.5 Map your old configuration

Use the [Values.yaml mapping reference](#9-valuesyaml-mapping-reference) below to translate your old community chart values to Enterprise-AIO values.

### 6.6 Using Kubernetes secrets (recommended)

Enterprise-AIO supports Kubernetes secrets for sensitive values. To enable:

```yaml
USE_SECRETS: "yes"
DATABASE_PASSWORD: my-db-password-secret   # This is now a secret name, not the password
REDIS_PASSWORD: my-redis-password-secret
NEXTCLOUD_PASSWORD: my-nc-password-secret
# ... all other secrets similarly
```

Create each secret before installing:

```sh
kubectl create secret generic -n <namespace> \
  --from-literal=my-db-password-secret=<actual-password> \
  my-db-password-secret
```

For more details, see [How to use secrets](./How-to-use-secrets).

---

## 7. Phase 5 — Install Enterprise-AIO and restore data

### 7.1 Validate your values.yaml (recommended)

```sh
helm lint . -f values.yaml
```

The Enterprise-AIO chart also includes a JSON schema (`values.schema.json`) that validates your values automatically during `helm install` / `helm upgrade`.

### 7.2 Perform a fresh install (first-time setup)

At this point, do a **first-time install** with an empty data state to let the management container initialize all services correctly. Do not restore data yet.

```sh
# If using git clone approach
helm install enterprise-aio . -f values.yaml -n <namespace>

# If using OCI approach
helm install enterprise-aio oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart \
  --version <version-tag> -f values.yaml -n <namespace>
```

Wait until all pods are running and the management container has completed its initial setup. Monitor progress:

```sh
kubectl get pods -n <namespace> -w
kubectl logs -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -f
```

The management container will:
1. Download the Enterprise Nextcloud archive
2. Install Nextcloud
3. Configure the database
4. Configure Redis
5. Enable and configure all enabled optional components
6. Set up cron jobs

### 7.3 Scale down all pods after initial setup

Once initialization is complete and Nextcloud is accessible (verify by visiting your domain), scale everything down before importing data:

```sh
kubectl scale deployment -n <namespace> nextcloud-enterprise-apache --replicas=0
kubectl scale deployment -n <namespace> nextcloud-enterprise-database --replicas=0
kubectl scale deployment -n <namespace> nextcloud-enterprise-nextcloud --replicas=0
kubectl scale deployment -n <namespace> nextcloud-enterprise-nextcloud-management --replicas=0
kubectl scale deployment -n <namespace> nextcloud-enterprise-redis --replicas=0
# Also scale down any optional components that were deployed:
# kubectl scale deployment -n <namespace> nextcloud-enterprise-collabora --replicas=0
# kubectl scale deployment -n <namespace> nextcloud-enterprise-talk --replicas=0
# kubectl scale deployment -n <namespace> nextcloud-enterprise-fulltextsearch --replicas=0
# kubectl scale deployment -n <namespace> nextcloud-enterprise-clamav --replicas=0
# kubectl scale deployment -n <namespace> nextcloud-enterprise-onlyoffice --replicas=0
```

### 7.4 Import the database

> **Note**: This step applies only if you are using Enterprise-AIO's **built-in PostgreSQL** database. If you configured an external database by pointing `POSTGRES_HOST` to your own server, restore the data directly to that external database using its native tooling and skip the rest of this section.

Find the name of the Enterprise-AIO database PVC and create a temporary pod to run the import:

```sh
kubectl get pvc -n <namespace>
# Look for the PVC associated with nextcloud-enterprise-database
```

Start the database pod temporarily to run the import:

```sh
kubectl scale deployment -n <namespace> nextcloud-enterprise-database --replicas=1
# Wait for the pod to be ready
kubectl wait --for=condition=ready pod -l app=nextcloud-enterprise-database -n <namespace> --timeout=120s

# Get the database pod name
DB_POD=$(kubectl get pod -n <namespace> -l app=nextcloud-enterprise-database -o jsonpath='{.items[0].metadata.name}')

# Copy the database dump into the pod
kubectl cp ./database-dump.sql -n <namespace> $DB_POD:/tmp/database-dump.sql

# Drop the existing (empty) database and recreate it
kubectl exec -n <namespace> $DB_POD -- psql -U nextcloud -d postgres -c "DROP DATABASE IF EXISTS nextcloud_database;"
kubectl exec -n <namespace> $DB_POD -- psql -U nextcloud -d postgres -c "CREATE DATABASE nextcloud_database OWNER nextcloud;"

# Import the dump
kubectl exec -n <namespace> $DB_POD -- psql -U nextcloud -d nextcloud_database -f /tmp/database-dump.sql

# Scale the database back down
kubectl scale deployment -n <namespace> nextcloud-enterprise-database --replicas=0
```

> ⚠️ **Note**: The built-in PostgreSQL container uses `nextcloud` as both the database user and the database name `nextcloud_database`. The password is whatever you set in `DATABASE_PASSWORD`.

### 7.5 Restore user data

Find the Enterprise-AIO nextcloud-data PVC:

```sh
kubectl get pvc -n <namespace> | grep nextcloud
# Look for nextcloud-enterprise-nextcloud-data (or similar)
```

Create a temporary pod to restore the data:

```sh
kubectl run data-restore -n <namespace> --image=alpine --overrides='
{
  "spec": {
    "containers": [{
      "name": "data-restore",
      "image": "alpine",
      "command": ["sleep", "3600"],
      "volumeMounts": [{"mountPath": "/mnt/ncdata", "name": "vol"}]
    }],
    "volumes": [{"name": "vol", "persistentVolumeClaim": {"claimName": "nextcloud-enterprise-nextcloud-data"}}]
  }
}' --restart=Never

# Wait for the pod to be ready
kubectl wait --for=condition=ready pod/data-restore -n <namespace> --timeout=60s

# Restore the data (this may take a while for large data sets)
kubectl cp ./nextcloud-data-backup/. -n <namespace> data-restore:/mnt/ncdata/

# Fix file ownership (Nextcloud runs as www-data, uid 33)
kubectl exec -n <namespace> data-restore -- chown -R 33:33 /mnt/ncdata

kubectl delete pod -n <namespace> data-restore
```

### 7.6 Scale all pods back up

```sh
kubectl scale deployment -n <namespace> nextcloud-enterprise-database --replicas=1
kubectl scale deployment -n <namespace> nextcloud-enterprise-redis --replicas=1
kubectl scale deployment -n <namespace> nextcloud-enterprise-nextcloud --replicas=1
kubectl scale deployment -n <namespace> nextcloud-enterprise-nextcloud-management --replicas=1
kubectl scale deployment -n <namespace> nextcloud-enterprise-apache --replicas=1
```

Wait for the management container to complete its post-start tasks:

```sh
kubectl logs -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -f
```

---

## 8. Phase 6 — Post-migration validation

### 8.1 Run Nextcloud maintenance tasks

Once all pods are running, perform a file scan and other database maintenance inside the Nextcloud management container:

```sh
# Scan all files (may take a long time)
kubectl exec -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -- \
  php occ files:scan --all

# Add missing database indices
kubectl exec -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -- \
  php occ db:add-missing-indices

# Add missing primary keys
kubectl exec -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -- \
  php occ db:add-missing-primary-keys

# Fix file caches if needed
kubectl exec -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -- \
  php occ files:repair-tree
```

### 8.2 Disable maintenance mode

```sh
kubectl exec -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -- \
  php occ maintenance:mode --off
```

### 8.3 Verify the deployment

- [ ] Log in to Nextcloud at `https://<NC_DOMAIN>`
- [ ] Verify that all users and their files are present
- [ ] Check the Nextcloud admin panel (`/settings/admin`) for any warnings
- [ ] Confirm that all previously installed apps are present and enabled
- [ ] Test file upload and download
- [ ] Test sharing functionality
- [ ] If Collabora/OnlyOffice was enabled, test document editing
- [ ] If Talk was enabled, test a call or chat
- [ ] Check `/settings/admin/overview` for any failing background jobs

### 8.4 Re-run full-text search indexing (if enabled)

If you enabled full-text search, trigger a re-index:

```sh
kubectl exec -n <namespace> deployment/nextcloud-enterprise-nextcloud-management -- \
  php occ fulltextsearch:index
```

---

## 9. Values.yaml mapping reference

The following table maps community chart values to their Enterprise-AIO equivalents.

### Core configuration

| nextcloud/helm | Enterprise-AIO | Notes |
|---|---|---|
| `nextcloud.host` | `NC_DOMAIN` | Domain only, no protocol |
| `nextcloud.username` | *(always `admin`)* | Admin username is fixed to `admin` in Enterprise-AIO |
| `nextcloud.password` | `NEXTCLOUD_PASSWORD` | |
| `nextcloud.mail.enabled` + settings | `SMTP_HOST`, `SMTP_SECURE`, `SMTP_PORT`, etc. | See SMTP section below |
| `nextcloud.trustedDomains` | `ADDITIONAL_TRUSTED_DOMAIN` | Enterprise-AIO supports one additional domain via this key; the primary domain is set by `NC_DOMAIN` |
| `nextcloud.datadir` | *(fixed at `/mnt/ncdata`)* | Data directory is fixed in Enterprise-AIO |
| `nextcloud.extraEnv` | *(no direct equivalent)* | Most config is via `values.yaml` keys |
| `nextcloud.configs` | *(no direct equivalent)* | The management container handles `config.php` automatically |
| `nextcloud.phpConfigs` | *(no direct equivalent)* | PHP memory and time limits are set via `NEXTCLOUD_MEMORY_LIMIT` and `NEXTCLOUD_MAX_TIME` |
| `nextcloud.memory_limit` | `NEXTCLOUD_MEMORY_LIMIT` | e.g. `512M` |
| `replicaCount` | `MAX_REPLICAS` | Enterprise-AIO uses HPA; set max replicas here |
| `hpa.enabled` | *(always enabled)* | Set `MAX_REPLICAS: 1` to effectively disable scaling |

### Database configuration

| nextcloud/helm | Enterprise-AIO | Notes |
|---|---|---|
| `internalDatabase.enabled: true` | *(default)* — leave `POSTGRES_HOST` as `nextcloud-enterprise-database` | Built-in database is PostgreSQL only |
| `externalDatabase.enabled: true` | Set `POSTGRES_HOST` to your external host | |
| `externalDatabase.type` | `DATABASE_TYPE` | `postgres` or `mysql` |
| `externalDatabase.host` | `POSTGRES_HOST` | |
| `externalDatabase.port` | `POSTGRES_PORT` | Default: `5432` |
| `externalDatabase.user` | `POSTGRES_USER` | |
| `externalDatabase.password` | `DATABASE_PASSWORD` | |
| `externalDatabase.database` | `POSTGRES_DB` | |
| `mariadb.enabled: true` | *(not supported as built-in)* | Use an external MariaDB and set `DATABASE_TYPE: mysql` |
| `postgresql.enabled: true` | *(use built-in by default)* | Or use `POSTGRES_HOST` for external PostgreSQL |

### Redis configuration

| nextcloud/helm | Enterprise-AIO | Notes |
|---|---|---|
| `redis.enabled: true` | *(default)* — leave `REDIS_HOST` as `nextcloud-enterprise-redis` | |
| `externalRedis.enabled: true` + `externalRedis.host` | `REDIS_HOST` | |
| `externalRedis.port` | `REDIS_PORT` | |
| `externalRedis.password` | `REDIS_PASSWORD` | |
| `redis.auth.password` | `REDIS_PASSWORD` | |

### Storage configuration

| nextcloud/helm | Enterprise-AIO | Notes |
|---|---|---|
| `persistence.storageClass` | `STORAGE_CLASS` | Must support RWX |
| `persistence.size` | `NEXTCLOUD_STORAGE_SIZE` | |
| `persistence.nextcloudData.size` | `NEXTCLOUD_DATA_STORAGE_SIZE` | |
| `persistence.nextcloudData.storageClass` | `STORAGE_CLASS_DATA` | Optional separate class for data |
| `nextcloud.objectStore.s3.*` | `OBJECTSTORE_S3_*` | See S3 section below |

### S3 / Object storage configuration

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `nextcloud.objectStore.s3.enabled` | *(set all `OBJECTSTORE_S3_*` values to enable)* |
| `nextcloud.objectStore.s3.bucket` | `OBJECTSTORE_S3_BUCKET` |
| `nextcloud.objectStore.s3.region` | `OBJECTSTORE_S3_REGION` |
| `nextcloud.objectStore.s3.host` | `OBJECTSTORE_S3_HOST` |
| `nextcloud.objectStore.s3.port` | `OBJECTSTORE_S3_PORT` |
| `nextcloud.objectStore.s3.accessKey` | `OBJECTSTORE_S3_KEY` |
| `nextcloud.objectStore.s3.secretKey` | `OBJECTSTORE_S3_SECRET` |
| `nextcloud.objectStore.s3.ssl` | `OBJECTSTORE_S3_SSL` |
| `nextcloud.objectStore.s3.usePathStyle` | `OBJECTSTORE_S3_USEPATH_STYLE` |
| `nextcloud.objectStore.s3.legacyAuth` | `OBJECTSTORE_S3_LEGACYAUTH` |
| `nextcloud.objectStore.s3.prefix` | `OBJECTSTORE_S3_OBJECT_PREFIX` |
| `nextcloud.objectStore.s3.storageClass` | `OBJECTSTORE_S3_STORAGE_CLASS` |
| `nextcloud.objectStore.s3.sse_c_key` | `OBJECTSTORE_S3_SSE_C_KEY` |
| `nextcloud.objectStore.s3.autoCreate` | `OBJECTSTORE_S3_AUTOCREATE` |

### SMTP / Mail configuration

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `nextcloud.mail.smtp.host` | `SMTP_HOST` |
| `nextcloud.mail.smtp.secure` | `SMTP_SECURE` (`ssl` or `tls`) |
| `nextcloud.mail.smtp.port` | `SMTP_PORT` |
| `nextcloud.mail.smtp.authtype` | `SMTP_AUTHTYPE` |
| `nextcloud.mail.smtp.name` | `SMTP_NAME` |
| `nextcloud.mail.smtp.password` | `SMTP_PASSWORD` |
| `nextcloud.mail.fromAddress` | `MAIL_FROM_ADDRESS` |
| `nextcloud.mail.domain` | `MAIL_DOMAIN` |

### Web server and ingress configuration

| nextcloud/helm | Enterprise-AIO | Notes |
|---|---|---|
| `ingress.enabled` | `INGRESS_ENABLED: "yes"` | |
| `ingress.annotations["cert-manager.io/cluster-issuer"]` | `INGRESS_CLUSTER_ISSUER` | Default: `letsencrypt-prod` |
| `ingress.className` | `INGRESS_CLASS_NAME` | Default: `nginx` |
| `service.type: LoadBalancer` | *(use scalable nginx sub-chart)* | Set `nginx.service.type: LoadBalancer` |
| `nginx.enabled: true` | `nginx.enabled: true` + `APACHE_HOST: &APACHE_HOST nextcloud-enterprise-nginx` | Replaces built-in Apache |
| `nginx.config.headers` | *(managed by Enterprise-AIO nginx image)* | |
| `phpClientHttpsFix` | *(handled automatically)* | |

### Resource configuration

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `resources` (top-level) | `NEXTCLOUD_RESOURCES` |
| `nginx.resources` | *(nginx sub-chart manages its own resources)* |
| `cronjob.sidecar.resources` | *(managed by management container)* |

### Upload limits

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `nginx.config.serverBlockCustom: client_max_body_size` | `NEXTCLOUD_UPLOAD_LIMIT` and `APACHE_MAX_SIZE` |
| `nginx.config.serverBlockCustom: fastcgi_read_timeout` | `NEXTCLOUD_MAX_TIME` |

### Security

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `nextcloud.securityContext` | `NEXTCLOUD_UGID` (for UID/GID) |
| `nextcloud.podSecurityContext` | `NEXTCLOUD_UGID` (for UID/GID) |
| `rbac.enabled` | *(service account via `SERVICE_ACCOUNT`)* |

### Collabora

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `collabora.enabled: true` | `COLLABORA_ENABLED: "yes"` |
| `collabora.collabora.aliasgroups[0].host` | *(automatically set from `NC_DOMAIN`)* |
| `collabora.collabora.extra_params` | `ADDITIONAL_COLLABORA_OPTIONS` |
| `collabora.collabora.server_name` | `COLLABORA_HOST` (if using external) |

### Cron jobs

| nextcloud/helm | Enterprise-AIO |
|---|---|
| `cronjob.enabled: true` | *(always enabled; handled by management container)* |
| `cronjob.type` | *(not applicable)* |
| `cronjob.cronjob.schedule` | *(fixed at every 5 minutes by management container)* |

### Monitoring / Metrics

| nextcloud/helm | Enterprise-AIO | Notes |
|---|---|---|
| `metrics.enabled` | *(not bundled)* | Use `SERVERINFO_TOKEN` to enable the serverinfo app token for external monitoring |
| `prometheus.serviceMonitor.enabled` | *(not bundled)* | |

---

## 10. Optional components configuration

### Imaginary (image processing)

In the community chart, Imaginary is a sub-chart. In Enterprise-AIO it is a bundled optional deployment:

```yaml
# community chart
imaginary:
  enabled: true

# Enterprise-AIO
IMAGINARY_ENABLED: "yes"
IMAGINARY_SECRET: "your-strong-secret"
```

### Collabora Online

```yaml
# Enterprise-AIO — bundled non-scalable
COLLABORA_ENABLED: "yes"
COLLABORA_DICTIONARIES: de_DE en_GB en_US es_ES fr_FR it nl pt_BR pt_PT ru
ADDITIONAL_COLLABORA_OPTIONS: ['--o:security.seccomp=true']

# Enterprise-AIO — external scalable
COLLABORA_ENABLED: "yes"
COLLABORA_HOST: "collabora.example.com"  # Your external Collabora host
```

### ClamAV antivirus

ClamAV is not available in the community chart but is available as an optional component in Enterprise-AIO:

```yaml
CLAMAV_ENABLED: "yes"
CLAMAV_STORAGE_SIZE: 1Gi
```

### Full-text search (Elasticsearch)

Full-text search is not available in the community chart. In Enterprise-AIO:

```yaml
FULLTEXTSEARCH_ENABLED: "yes"
FULLTEXTSEARCH_PASSWORD: "your-strong-password"
FULLTEXTSEARCH_JAVA_OPTIONS: -Xms512M -Xmx512M
ELASTICSEARCH_STORAGE_SIZE: 5Gi
```

### Nextcloud Talk with High-Performance Backend

Talk is not available in the community chart. In Enterprise-AIO:

```yaml
TALK_ENABLED: "yes"
SIGNALING_SECRET: "your-strong-secret"
TALK_INTERNAL_SECRET: "your-strong-internal-secret"
TURN_SECRET: "your-strong-turn-secret"
TALK_PORT: 3478
```

### Custom certificates

If your existing deployment uses custom trusted certificates (e.g. for self-signed S3 or LDAP), add them to `values.yaml`:

```yaml
NEXTCLOUD_TRUSTED_CERTIFICATES:
  MY_CUSTOM_CA: |
    -----BEGIN CERTIFICATE-----
    <your-certificate-content>
    -----END CERTIFICATE-----
```

For details, see [How to add custom certificates](./How-to-add-custom-certificates).

---

## 11. Rollback procedure

If something goes wrong during the migration, follow these steps to roll back.

### 11.1 Restore from backup

Scale everything down:

```sh
kubectl scale deployment -n <namespace> --replicas=0 \
  nextcloud-enterprise-apache \
  nextcloud-enterprise-database \
  nextcloud-enterprise-nextcloud \
  nextcloud-enterprise-nextcloud-management \
  nextcloud-enterprise-redis
```

Restore data PVCs from the backups taken in Phase 1 using the same `kubectl cp` approach described in [section 7.5](#75-restore-user-data).

Restore the database from your original backup.

### 11.2 Revert the Helm release

```sh
helm rollback enterprise-aio -n <namespace>
```

Or uninstall entirely and re-install your original community chart:

```sh
helm uninstall enterprise-aio -n <namespace>
helm install nextcloud . -f values.yaml.backup-<date> -n <namespace>
```

> ⚠️ Uninstalling Enterprise-AIO does **not** automatically delete the PVCs it created. Delete them manually only after confirming your rollback is working correctly:
> ```sh
> kubectl delete pvc -n <namespace> --selector=app.kubernetes.io/instance=enterprise-aio
> ```

---

## Additional resources

- [Enterprise-AIO Helm Chart README](https://github.com/nextcloud-gmbh/enterprise-aio/blob/main/nextcloud-enterprise-helm-chart/readme.md)
- [How to use secrets](./How-to-use-secrets)
- [How to add custom certificates](./How-to-add-custom-certificates)
- [Resource requests and limits](./Resource-requests-and-limits)
- [Annotations and labels](./Annotations-and-labels)
- [Scalable NGINX setup](https://github.com/nextcloud-gmbh/enterprise-aio/blob/main/scalable-nginx/readme.md)
- [OpenShift overview](./OpenShift-overview)
- [Airgapped installation](./Airgapped-installation)
- [Podman deployment](./Podman)
- [Nextcloud Enterprise Portal](https://portal.nextcloud.com/categories/Scalability/Enterprise-AIO)
