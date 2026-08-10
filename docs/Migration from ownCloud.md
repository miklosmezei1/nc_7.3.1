# Migration from ownCloud to Enterprise-AIO

## Process steps

1. Migrate ownCloud to Nextcloud 25
2. Migration to PostreSQL and export of database
3. Extract data & config from Nextcloud 25
4. Initialize Enterprise-AIO v28
5. Import db, data & config parameters
6. Restart E-AIO

## Details

--- PREVIEW ---

#### Migrate ownCloud to Nextcloud 25

Nextcloud offers an integrated migration from ownCloud to Nextcloud. This is a drop-in migration where all existing data, most apps and configuration is retained.
For the detail steps, please contact your account manager.

#### Migration to PostreSQL and export of database

If your former installation didn't use Postgresql already, Nextcloud needs to operate on PostreSQL as this is used in the target implementation of the Enterprise-AIO.

1. Install Postgresql on your former installation: on a Debian based OS should the following command work:

   ```
   sudo apt update && sudo apt install postgresql -y
   ```
2. Create a new database by running:

   ```
   export PG_USER="ncadmin" # This is a temporary user that gets created for the dump but is then overwritten by the correct one later on
   export PG_PASSWORD="my-temporary-password"
   export PG_DATABASE="nextcloud_db"
   sudo -u postgres psql <<END
   CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD' CREATEDB;
   CREATE DATABASE $PG_DATABASE WITH OWNER $PG_USER TEMPLATE template0 ENCODING 'UTF8';
   GRANT ALL PRIVILEGES ON DATABASE $PG_DATABASE TO $PG_USER;
   GRANT ALL PRIVILEGES ON SCHEMA public TO $PG_USER;
   END
   ```
3. Run the following command to start the conversion:

   ```sh
   php occ db:convert-type --all-apps --password "$PG_PASSWORD" pgsql "$PG_USER" 127.0.0.1 "$PG_DATABASE"
   ```
4. Export the database and save the database-dump.sql locally

   ```
   sudo -u postgres pg_dump "$PG_DATABASE" > /database-dump.sql
   ```
5. Modify the local copy of the database dump. This is required as the data root will be different in the new system.
6. Open the sql file in an editor and search for local::/your/old/datadir/\*

   This will be found in the section of the table oc_storages and needs to be changed to local::/mnt/ncdata/\* in every location

#### Extract data & config from Nextcloud 25

If the existing ownCloud->Nextcloud 25 is operated in a container, this can be used to copy the data folder. This will create a local copy of all files and config.

```
docker cp oc-migration:/mnt/data/. ./data
```

#### Initialize Enterprise-AIO v28

Start an Enterprise-AIO as described here
Important: Maintain the ENTERPRISE_ARCHIVE_URLin the value.yaml to use a Nextcloud 28 archive
After the Enterprise-AIO was initialized, stop the current setup

```
kubectl scale deployment nextcloud-enterprise-apache --replicas=0 
kubectl scale deployment nextcloud-enterprise-database --replicas=0 
kubectl scale deployment nextcloud-enterprise-nextcloud --replicas=0 
kubectl scale deployment nextcloud-enterprise-nextcloud-management --replicas=0 
kubectl scale deployment nextcloud-enterprise-redis --replicas=0
```

#### Import db, data & config parameters

The following example will import the database dump into the PVC of the AIO by creating a temporary pod

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: temp-pod
spec:
  containers:
  - name: temp-container
    image: alpine
    command: [ "sleep", "3600" ] # Keeps the pod running for an hour
    volumeMounts:
    - mountPath: /mnt/data
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: nextcloud-enterprise-database-dump
EOF

kubectl cp database-dump.sql temp-pod:/mnt/data/database-dump.sql -c temp-container
kubectl exec -it temp-pod -c temp-container -- chmod 777 /mnt/data/database-dump.sql
kubectl exec -it temp-pod -c temp-container -- rm /mnt/data/initial-cleanup-done
kubectl delete pod temp-pod
```

The following example will import the data  into the PVC of the AIO by creating a temporary pod

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: temp-pod
spec:
  containers:
  - name: temp-container
    image: alpine
    command: [ "sleep", "3600" ] # Keeps the pod running for an hour
    volumeMounts:
    - mountPath: /mnt/ncdata
      name: ncdata
  volumes:
  - name: ncdata
    persistentVolumeClaim:
      claimName: nextcloud-enterprise-nextcloud-data
EOF

kubectl exec -it temp-pod -- sh -c 'rm -rf /mnt/ncdata/*'
kubectl cp ./data/files/. temp-pod:/mnt/ncdata/
kubectl exec -it temp-pod -- sh -c 'chown -R 33:0 /mnt/ncdata/'
kubectl exec -it temp-pod -- sh -c 'chmod -R 750 /mnt/ncdata/'
kubectl delete pod temp-pod
```

The following example will open a temporary pod to maintain the config.php

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: temp-edit-pod
spec:
  containers:
  - name: temp-container
    image: alpine
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - mountPath: /var/www/html
      name: nextcloud-data
  volumes:
  - name: nextcloud-data
    persistentVolumeClaim:
      claimName: nextcloud-enterprise-nextcloud
EOF

kubectl exec -it temp-edit-pod -- sh -c "apk add --no-cache nano && nano /var/www/html/config/config.php"

*** update the passwordsalt, secret, instanceid with the values from the old installation ***

kubectl delete pod temp-edit-pod
```

#### Restart E-AIO

Restart the existing Enterprise-AIO

```
kubectl scale deployment nextcloud-enterprise-apache --replicas=1 
kubectl scale deployment nextcloud-enterprise-database --replicas=1 
kubectl scale deployment nextcloud-enterprise-nextcloud --replicas=1 
kubectl scale deployment nextcloud-enterprise-nextcloud-management --replicas=1 
kubectl scale deployment nextcloud-enterprise-redis --replicas=1
```
