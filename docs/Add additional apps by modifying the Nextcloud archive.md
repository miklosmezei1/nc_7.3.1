# Enterprise-AIO - Add additional apps by modifying the Nextcloud archive 

As an alternative to the [archives PVC or NFS mount](https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/values.yaml-ARCHIVES_PVC_NAME-for-local-archives) it is possible to add additional apps to the installation by modify the Nextcloud Enterprise archive in a supported way. This is especially useful in offline (airgapped) scenarios. 

Note: *This is work-in-progress. Feedback is very welcome!*

## Process steps

0. Requirements
1. Download zip file
2. Download the app archives and extract them
3. Put the apps into the zip file
4. Upload the archive onto a local web server
5. Prepare Helm Charts

## Details
--- PREVIEW ---

### Requirements
For this specific feature to work correctly, E-AIO v4.6.0 or higher is required.

### Download zip file
First of all, you need a current Nextcloud Enterprise archive. You can retrieve one by navigating to [https://portal.nextcloud.com/](https://portal.nextcloud.com/), log in and retrieving one from the left sidebar. Alternatively, you can navigate to the [values.yaml](https://github.com/nextcloud-gmbh/enterprise-aio/blob/main/nextcloud-enterprise-helm-chart/values.yaml) file and look for the `ENTERPRISE_ARCHIVE_URL` variable. You can simply use that link to download the archive.

### Download the app archives and extract them
Next, navigate to our public app store and retrieve all the apps that you need to ship that are not bundled within the archive by default. For example the [Client Push](https://apps.nextcloud.com/apps/notify_push) app needs to be manually added all the time. You can navigate to the [releases page](https://apps.nextcloud.com/apps/notify_push/releases) and download a version that is compatible with the Nextcloud Archive that you just downloaded, for example, `Nextcloud 32`.

As soon as you downloaded the app, for example, the `notify_push-v1.2.0.tar.gz` file, extract it so that you can see the folder structure and all source files.

### Put the apps into the zip file
Next, you should have a folder like `notify_push` in which the files are located.

Now, in the zip archive of Nextcloud Enterprise, there is a `nextcloud` directory. Inside that, create a folder that must be named `custom_apps`.

Into this custom_apps directory, place the notify_push app and all additional apps that you want to ship.

Now, repack the whole zip file into one file with the same naming pattern that was used before.

### Upload the archive onto a local web server
Next, upload the archive onto a local web server so that it is reachable from within the cluster.

### Prepare Helm charts
Lastly, update the `ENTERPRISE_ARCHIVE_URL` to point at the modified enterprise zip archive on your local web server and run `helm install` or `helm upgrade`.
