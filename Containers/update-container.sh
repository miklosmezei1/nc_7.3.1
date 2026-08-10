#!/bin/bash

set -ex

git clone https://github.com/nextcloud/all-in-one.git --depth 1
rm -r ./Containers/nextcloud/Dockerfile
rm -r ./Containers/nextcloud-management/*
rm ./all-in-one/Containers/nextcloud/config/aio.config.php
sed -i "/^# AIO settings start/,/^# AIO settings end.*/d" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i "/^# Download Nextcloud archive start/,/^# Download Nextcloud archive end.*/d" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i "/^# AIO cloning start/,/^# AIO cloning end.*/d" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i 's|^USER root|USER 33|' ./all-in-one/Containers/nextcloud/Dockerfile
# shellcheck disable=SC1003
sed -i '/^        pdo_pgsql.*/a\ \ \ \ \ \ \ \ pdo_mysql \\' ./all-in-one/Containers/nextcloud/Dockerfile
sed -i "s|^        coreutils|        coreutils unzip openldap-clients|" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i "s|chown www-data:root|chmod 777|" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i "s|session.save_handler = redis|session.save_handler = \${REDIS_MODE}|" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i "s|session.save_path.*\;|session.save_path = \"\${REDIS_CONNECT_STRING}\"'\;|" ./all-in-one/Containers/nextcloud/Dockerfile
sed -i '/^LABEL/,$d' ./all-in-one/Containers/nextcloud/Dockerfile

cp ./all-in-one/Containers/nextcloud/Dockerfile ./Containers/nextcloud/
cp ./all-in-one/Containers/nextcloud/healthcheck.sh ./Containers/nextcloud/
cp -r ./all-in-one/Containers/nextcloud/* ./Containers/nextcloud-management/
rm ./Containers/nextcloud-management/README.md ./Containers/nextcloud-management/upgrade-latest-major.sh
rm -rf ./all-in-one

sed -i '/^COPY/d' ./Containers/nextcloud/Dockerfile
sed -i '/^CMD /d' ./Containers/nextcloud/Dockerfile
sed -i 's|^ENV SOURCE_LOCATION=.*|COPY --chmod=775 healthcheck.sh /healthcheck.sh|' ./Containers/nextcloud/Dockerfile
sed -i 's|^ENTRYPOINT.*|ENTRYPOINT \["php-fpm"\]|' ./Containers/nextcloud/Dockerfile
sed -i 's|^nc -z |# nc -z |' ./Containers/nextcloud/healthcheck.sh
sed -i '/mv \/\*.php \/usr\/src\/nextcloud\/config\//d' ./Containers/nextcloud/Dockerfile
sed -i '/\/supervisord.conf/d' ./Containers/nextcloud/Dockerfile

sed -i "/^# Create cert bundle end # Do not remove or change this line!$/r ./Containers/update-container.d/management-entrypoint-top.sh" ./Containers/nextcloud-management/entrypoint.sh
sed -i "s|Containers/nextcloud/||" ./Containers/nextcloud-management/Dockerfile
cp ./Containers/update-container.d/management-healthcheck.sh ./Containers/nextcloud-management/healthcheck.sh

rm ./Containers/nextcloud-management/start.sh
cp ./Containers/update-container.d/management-supervisord.conf ./Containers/nextcloud-management/supervisord.conf
sed -i 's|^ENV SOURCE_LOCATION.*|ENV SOURCE_LOCATION=/mnt/ncdata/nextcloud-enterprise-source/nextcloud|' ./Containers/nextcloud-management/Dockerfile
sed -i 's|mv /\*.php /usr/src/nextcloud/config/|mkdir -p /usr/src/config\; mv /\*.php /usr/src/config/|' ./Containers/nextcloud-management/Dockerfile
sed -i 's|^ENTRYPOINT.*|ENTRYPOINT \["/entrypoint.sh"\]|' ./Containers/nextcloud-management/Dockerfile
sed -i "/^# Do not skip major versions start/,/^# Do not skip major versions end.*/d" ./Containers/nextcloud-management/entrypoint.sh
sed -i "/^# AIO update to latest start/,/^# AIO update to latest end.*/d" ./Containers/nextcloud-management/entrypoint.sh
sed -i "/^# Check connection to appstore start/,/^# Check connection to appstore end.*/d" ./Containers/nextcloud-management/entrypoint.sh
sed -i "/^# AIO one-click settings start/,/^# AIO one-click settings end.*/d" ./Containers/nextcloud-management/entrypoint.sh
sed -i "/^# AIO app start/,/^# AIO app end.*/d" ./Containers/nextcloud-management/entrypoint.sh
sed -i 's|^# Do not skip major versions placeholder.*|            echo "Multiple major updates are not supported" \&\& exit 1|' ./Containers/nextcloud-management/entrypoint.sh
sed -i 's|bash /notify.sh|echo|' ./Containers/nextcloud-management/entrypoint.sh
sed -i '/app:enable nextcloud-aio/d' ./Containers/nextcloud-management/entrypoint.sh
sed -i "/^#\!\/bin\/bash$/r ./Containers/update-container.d/management-run-exec-commands.sh" ./Containers/nextcloud-management/run-exec-commands.sh
cat ./Containers/update-container.d/management-entrypoint-bottom.sh >> ./Containers/nextcloud-management/entrypoint.sh

set -x
git clone https://github.com/bitnami/containers bitnami --depth 1
rm -rf ./Containers/nginx
mkdir -p ./Containers/nginx
# shellcheck disable=SC2143
if [ -n "$(find bitnami/bitnami/nginx -maxdepth 1 -mindepth 1 -type d | grep -v '1.30\|1.31')" ]; then
    echo "Found another bitnami nginx version. Should use that instead by updating the update-container.sh script."
    exit 1
fi
cp -r bitnami/bitnami/nginx/1.31/debian-12/* ./Containers/nginx/
rm -rf bitnami

# Remove the global keepalive_timeout so that ours from the nginx config map is used
sed -i '/keepalive_timeout/d' ./Containers/nginx/rootfs/opt/bitnami/nginx/conf/nginx.conf

set +x

chmod -R 777 ./Containers
