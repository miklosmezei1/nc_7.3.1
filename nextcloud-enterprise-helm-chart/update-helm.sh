#!/bin/bash

set -ex

DOCKER_TAG="$1"

git clone https://github.com/nextcloud/all-in-one.git --depth 1
find ./nextcloud-enterprise-helm-chart/templates/ -name "nextcloud-enterprise-*.yaml" -not -name "nextcloud-enterprise-ingress.yaml" -not -name "nextcloud-enterprise-openshift-route.yaml" -delete
rm -f ./nextcloud-enterprise-helm-chart/values.yaml
cp -r ./all-in-one/nextcloud-aio-helm-chart/templates/nextcloud-aio-* ./nextcloud-enterprise-helm-chart/templates/
cp  ./all-in-one/nextcloud-aio-helm-chart/values.yaml ./nextcloud-enterprise-helm-chart/
rm -r ./all-in-one

# Install yq
wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod +x /usr/local/bin/yq

cd nextcloud-enterprise-helm-chart
sudo apt-get install rename -y --no-install-recommends
rename -v 's/nextcloud-aio-/nextcloud-enterprise-/' ./templates/*.yaml
sed -i 's|nextcloud-aio|nextcloud-enterprise|g' ./templates/*.yaml
sed -i '/ADDITIONAL_APKS/d' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i '/^  replicas:/d' ./templates/*-deployment.yaml
sed -i '/ADDITIONAL_APKS/d' ./values.yaml
sed -i '/ADDITIONAL_PHP_EXTENSIONS/d' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i '/ADDITIONAL_PHP_EXTENSIONS/d' ./values.yaml
# shellcheck disable=SC1083
find ./ -name '*deployment.yaml' -exec sed -i '/image: .*nextcloud.*/s/$/"/;' \{} \;
# shellcheck disable=SC1083
find ./ -name '*deployment.yaml' -exec sed -i 's@image: .*nextcloud-releases/@image: "{{ .Values.IMAGE_MIRROR_PREFIX }}{{ .Values.NEXTCLOUD_IMAGE_ORG }}/@;' \{} \;
# shellcheck disable=SC1083
find ./ -name '*deployment.yaml' -exec sed -i 's@image: .*alpine:@image: "{{ .Values.IMAGE_MIRROR_PREFIX }}{{ .Values.NEXTCLOUD_IMAGE_ORG }}/aio-alpine:@;' \{} \;
# shellcheck disable=SC1083
sed -i 's|{{-|##-|' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml 
sed -i '/# AIO-config/d' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i "/^# AIO settings start/,/^# AIO settings end.*/d" ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i 'del(.spec.template.spec.containers.[].volumeMounts[] | select(.name == "nextcloud-enterprise-nextcloud-trusted-cacerts"))' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i 'del(.spec.template.spec.volumes[] | select(.name == "nextcloud-enterprise-nextcloud-trusted-cacerts"))' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i 's|{{|##|' ./templates/nextcloud-enterprise-talk-deployment.yaml
yq -i 'del(.spec.template.spec.containers.[].volumeMounts)' ./templates/nextcloud-enterprise-talk-deployment.yaml
yq -i 'del(.spec.template.spec.volumes)' ./templates/nextcloud-enterprise-talk-deployment.yaml
sed -i '/nextcloud-enterprise-nextcloud-trusted-cacerts/d' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml ./templates/nextcloud-enterprise-talk-deployment.yaml
sed -i 's|##|\{\{|' ./templates/nextcloud-enterprise-talk-deployment.yaml
find ./ -name "*nextcloud-enterprise-nextcloud-trusted-cacerts-persistentvolumeclaim.yaml" -delete
sed -i '/TRUSTED_CACERTS_DIR/d' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i '/TRUSTED_CACERTS_/d' ./values.yaml
sed -i 's|^NAMESPACE:.*|NAMESPACE: \&NAMESPACE default        # By changing this, you can adjust the namespace of the installation which allows to install multiple instances on one kubernetes cluster !!! Keep the \&NAMESPACE anchor in chase you want to use nginx !!!|' ./values.yaml

sed -i "/^.*- \/nextcloud-enterprise-nextcloud/a\ \ \ \ \ \ \ \ \ \ \ \ - \/nextcloud-enterprise-nextcloud-data" ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i "/^.*mountPath: \/nextcloud-enterprise-nextcloud/a\ \ \ \ \ \ \ \ \ \ \ \ - name: nextcloud-enterprise-nextcloud-data\n\ \ \ \ \ \ \ \ \ \ \ \ \ \ mountPath: \/nextcloud-enterprise-nextcloud-data" ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i 's|value: nextcloud$|value: "{{ .Values.POSTGRES_USER }}"|' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i 's|value: "5432"$|value: "{{ .Values.POSTGRES_PORT }}"|' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
sed -i 's|value: nextcloud_database$|value: "{{ .Values.POSTGRES_DB }}"|' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
cp ./templates/nextcloud-enterprise-nextcloud-deployment.yaml ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i 'del(.spec.template.spec.initContainers)' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i 'del(.spec.template.spec.containers.[].env)' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i 'del(.spec.template.spec.terminationGracePeriodSeconds)' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i '.spec.template.spec.containers.[].image = "{{ .Values.IMAGE_MIRROR_PREFIX }}{{ .Values.NEXTCLOUD_IMAGE_ORG }}/nce-php-fpm"' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i 'del(.spec.template.spec.containers.[].ports[] | select(.containerPort == 9000))' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i 'del(.spec.template.spec.containers.[].ports[] | select(.containerPort == 9001))' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
yq -i '.spec.template.spec.containers.[].image = "{{ .Values.IMAGE_MIRROR_PREFIX }}{{ .Values.NEXTCLOUD_IMAGE_ORG }}/nce-php-fpm-mgmt"' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i '.spec.template.spec.containers.[].name = "nextcloud-enterprise-nextcloud-management"' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i '.metadata.labels."io.kompose.service" = "nextcloud-enterprise-nextcloud-management"' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i '.metadata.name = "nextcloud-enterprise-nextcloud-management"' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i '.spec.selector.matchLabels."io.kompose.service" = "nextcloud-enterprise-nextcloud-management"' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
yq -i '.spec.template.metadata.labels."io.kompose.service" = "nextcloud-enterprise-nextcloud-management"' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|##-|{{-|' ./templates/nextcloud-enterprise-nextcloud-deployment.yaml ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
cp ./templates/nextcloud-enterprise-nextcloud-service.yaml ./templates/nextcloud-enterprise-nextcloud-management-service.yaml
yq -i 'del(.spec.ports[] | select(.name == "9001"))' ./templates/nextcloud-enterprise-nextcloud-service.yaml
yq -i 'del(.spec.ports[] | select(.name == "9000"))' ./templates/nextcloud-enterprise-nextcloud-management-service.yaml
# shellcheck disable=SC1083
find ./ -name '*deployment.yaml' -exec sed -i 's|value: "6379"$|value: "{{ .Values.REDIS_PORT \| default "6379" }}"|'  \{} \;
sed -i 's|value: http$|value: "{{ .Values.FULLTEXTSEARCH_PROTOCOL \| default "http" }}"|' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i '/REDIS_HOST_PASSWORD/d;/REDIS_PASSWORD/d' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
# initcontainers config
cat << EOL > /tmp/initcontainers.config
      initContainers:
        - name: wait-for-container
          image: "{{ .Values.IMAGE_MIRROR_PREFIX }}{{ .Values.NEXTCLOUD_IMAGE_ORG }}/nce-php-fpm"
          command:
            - "bash"
            - "-c"
            - "while ! nc -z nextcloud-enterprise-nextcloud-management 9001; do echo 'Waiting for Nextcloud to be ready'; sleep 5; done"
          securityContext:
            # The items below only work in container context
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
EOL
# shellcheck disable=SC1083
find ./ -name '*nextcloud-deployment.yaml' -exec sed -i "/\ \ \ \ spec:/r /tmp/initcontainers.config"  \{} \;

# pullsecret config
cat << EOL > /tmp/pullsecret.config
      {{- if .Values.SERVICE_ACCOUNT }}
      serviceAccountName: "{{ .Values.SERVICE_ACCOUNT }}"
      {{- end }}
      {{- if .Values.IMAGE_PULL_SECRET }}
      imagePullSecrets:
        - name: {{ .Values.IMAGE_PULL_SECRET }}
      {{- end }}
EOL
# shellcheck disable=SC1083
find ./ -name '*deployment.yaml' -exec sed -i "/\ \ \ \ spec:/r /tmp/pullsecret.config"  \{} \;
sed -i 's|nextcloud-enterprise-nextcloud|nextcloud-enterprise-nextcloud-management|g' ./templates/nextcloud-enterprise-nextcloud-management-service.yaml
sed -i 's|value: nextcloud-enterprise-fulltextsearch|value: "{{ .Values.FULLTEXTSEARCH_HOST \| default "nextcloud-enterprise-fulltextsearch" }}"|g' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|value: "9200"|value: "{{ .Values.FULLTEXTSEARCH_PORT \| default "9200" }}"|g' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|value: elastic|value: "{{ .Values.FULLTEXTSEARCH_USER \| default "elastic" }}"|g' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|value: nextcloud-enterprise$|value: "{{ .Values.FULLTEXTSEARCH_INDEX \| default "nextcloud-aio" }}"|g' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|{{- if eq .Values.FULLTEXTSEARCH_ENABLED "yes" }}|{{- if and (eq (.Values.FULLTEXTSEARCH_HOST \| default "nextcloud-enterprise-fulltextsearch") "nextcloud-enterprise-fulltextsearch") (eq .Values.FULLTEXTSEARCH_ENABLED "yes") }}|g' ./templates/nextcloud-enterprise-fulltextsearch-*.yaml ./templates/nextcloud-enterprise-elasticsearch-persistentvolumeclaim.yaml
sed -i 's|value: nextcloud-enterprise-onlyoffice|value: "{{ .Values.ONLYOFFICE_HOST \| default "nextcloud-enterprise-onlyoffice" }}"|g' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|{{- if eq .Values.ONLYOFFICE_ENABLED "yes" }}|{{- if and (eq (.Values.ONLYOFFICE_HOST \| default "nextcloud-enterprise-onlyoffice") "nextcloud-enterprise-onlyoffice") (eq .Values.ONLYOFFICE_ENABLED "yes") }}|g' ./templates/nextcloud-enterprise-onlyoffice-*.yaml ./templates/nextcloud-enterprise-onlyoffice-persistentvolumeclaim.yaml
sed -i 's|value: nextcloud-enterprise-collabora|value: "{{ .Values.COLLABORA_HOST }}"|g' ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i 's|{{- if eq .Values.COLLABORA_ENABLED "yes" }}|{{- if and (eq .Values.COLLABORA_HOST "nextcloud-enterprise-collabora") (eq .Values.COLLABORA_ENABLED "yes") }}|g' ./templates/nextcloud-enterprise-collabora-*.yaml
sed -i 's|{{- if eq .Values.TALK_ENABLED "yes" }}|{{- if and (eq .Values.TALK_HOST "nextcloud-enterprise-talk") (eq .Values.TALK_ENABLED "yes") }}|g' ./templates/nextcloud-enterprise-talk-*.yaml
sed -i 's|value: nextcloud-enterprise-nextcloud|value: nextcloud-enterprise-nextcloud-management|g' ./templates/nextcloud-enterprise-notify-push-deployment.yaml
sed -i "s|/nce-php-fpm-mgmt.*|/nce-php-fpm-mgmt:$DOCKER_TAG\"|" ./templates/nextcloud-enterprise-nextcloud-management-deployment.yaml
sed -i "s|/nce-php-fpm.*|/nce-php-fpm:$DOCKER_TAG\"|" ./templates/nextcloud-enterprise-nextcloud-deployment.yaml
# shellcheck disable=SC1083
find ./ -name "*nextcloud-enterprise-nextcloud*persistentvolumeclaim.yaml" -exec sed -i "s|ReadWriteOnce|ReadWriteMany|g" \{} \; 

cat << VALUES >> values.yaml

IMAGE_MIRROR_PREFIX: ghcr.io/         # Setting this allows you to pull Nextcloud images through a mirror registry. It needs a trailing slash!
NEXTCLOUD_IMAGE_ORG: nextcloud-releases          # Setting this allows you to change the image's org name in case a different image needs to be used e.g. for compliance reasons.

VALUES

OPTIONAL_CONTAINERS=(apache database redis)
for name in "${OPTIONAL_CONTAINERS[@]}"; do
    if [ "$name" = apache ]; then
        variable=APACHE_HOST
        value=nextcloud-enterprise-apache
    elif [ "$name" = redis ]; then
        variable=REDIS_HOST
        value=nextcloud-enterprise-redis
    elif [ "$name" = database ]; then
        variable=POSTGRES_HOST
        value=nextcloud-enterprise-database
    elif [ "$name" = notify-push ]; then
        variable=NOTIFY_PUSH_HOST
        value=nextcloud-enterprise-notify-push
    fi
    # shellcheck disable=SC1083
    find ./ -name "*nextcloud-enterprise-$name-deployment.yaml" -exec sed -i "1i\\{{- if eq .Values.$variable \"$value\" }}" \{} \; 
    # shellcheck disable=SC1083
    find ./ -name "*-deployment.yaml" -not -name "*nextcloud-enterprise-$name-deployment.yaml" -exec sed -i "s|$value$|\"{{ .Values.$variable }}\"|g" \{} \; 
    # shellcheck disable=SC1083
    find ./ -name "*nextcloud-enterprise-$name-deployment.yaml" -exec sed -i "$ a {{- end }}" \{} \; 
    # shellcheck disable=SC1083
    find ./ -name "*nextcloud-enterprise-$name-service.yaml" -exec sed -i "1i\\{{- if eq .Values.$variable \"$value\" }}" \{} \; 
    # shellcheck disable=SC1083
    find ./ -name "*nextcloud-enterprise-$name-service.yaml" -exec sed -i "$ a {{- end }}" \{} \; 
    # shellcheck disable=SC1083
    find ./ -name "*nextcloud-enterprise-$name-persistentvolumeclaim.yaml" -exec sed -i "1i\\{{- if eq .Values.$variable \"$value\" }}" \{} \; 
    # shellcheck disable=SC1083
    find ./ -name "*nextcloud-enterprise-$name-persistentvolumeclaim.yaml" -exec sed -i "$ a {{- end }}" \{} \; 
    if [ "$variable" = APACHE_HOST ]; then
      echo "$variable: &APACHE_HOST $value        # Setting this to something else than '$value' (keep the '&APACHE_HOST' before the actual value) will disable the functionality in this helm chart and allows you to use your own external service" >> values.yaml
    else
      echo "$variable: $value        # Setting this to something else than '$value' will disable the functionality in this helm chart and allows you to use your own external service" >> values.yaml
    fi
    if [ "$name" = database ]; then
        # shellcheck disable=SC1083
        find ./ -name "*nextcloud-enterprise-$name-dump-persistentvolumeclaim.yaml" -exec sed -i "1i\\{{- if eq .Values.$variable \"$value\" }}" \{} \; 
        # shellcheck disable=SC1083
        find ./ -name "*nextcloud-enterprise-$name-dump-persistentvolumeclaim.yaml" -exec sed -i "$ a {{- end }}" \{} \; 
        # shellcheck disable=SC2129
        echo "POSTGRES_PORT: 5432        # This allows to configure the port on which the database is listening. ⚠️ Please note that the bundled Postgres container only supports port 5432!" >> values.yaml
        # shellcheck disable=SC2129
        echo "DATABASE_TYPE: postgres        # This allows to configure the database type for usage with an external database (the integrated one only supports 'postgres' as value). You also need to adjust POSTGRES_HOST to use your own service in that case. ⚠️ allowed values are currently 'postgres' and 'mysql'" >> values.yaml
        # shellcheck disable=SC2129
        echo "# NEXTCLOUD_TRUSTED_CERTIFICATES.MYSQL: # This allows to enable TLS connections for mysql. Please configure this further down at the NEXTCLOUD_TRUSTED_CERTIFICATES section. Also note that the built-in database container does not support this." >> values.yaml
        # shellcheck disable=SC2129
        echo "# DATABASE_PASSWORD:           # This allows to set the db password which is getting set at the very top of this values.yaml file." >> values.yaml
        # shellcheck disable=SC2129
        echo "POSTGRES_DB: nextcloud_database        # This allows to configure the database name for usage with an external database (the integrated one only supports 'nextcloud_database' as value). You also need to adjust POSTGRES_HOST to use your own service in that case. ⚠️ Make sure to use a different database for every instance if you use a global postgres server for all instances!" >> values.yaml
        # shellcheck disable=SC2129
        echo "# NEXTCLOUD_TRUSTED_CERTIFICATES.POSTGRES: # This allows to enable TLS connections for postgres. Please configure this further down at the NEXTCLOUD_TRUSTED_CERTIFICATES section. Also note that the built-in database container does not support this." >> values.yaml
        # shellcheck disable=SC2129
        echo "POSTGRES_USER: nextcloud        # This allows to configure the database user for usage with an external database (the integrated one only supports 'nextcloud' as value). It needs to be set to something else than 'nextcloud' if you want to use it with an external database! You also need to adjust POSTGRES_HOST to use your own service in that case." >> values.yaml
    elif [ "$name" = redis ]; then
        # shellcheck disable=SC2129
        echo 'REDIS_MODE: "redis"        # This allows to configure the redis mode that is used. ⚠️ Only "redis" and "rediscluster" are supported. Please note that the built-in redis container only supports "redis" mode! Additionally, please note that the rediscluster mode is currently only compatible with redis cluster v7! Also, the whiteboard app currently does not support redis cluster.' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_DB_INDEX: "0"        # This allows to configure the redis db index that is used. ⚠️ Make sure to set a different db index for every instance if you use a global redis server for all instances! Also, the internal redis container only supports this value being set to "0"!' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PREFIX:         # This allows to configure the redis custom prefix inside Nextcloud. This allows to use multiple Nextcloud instances with one redis cluster instances. ⚠️ Make sure to set a different prefix for every instance if you use a global cluster for all instances! Please note that the whiteboard app currently does not support this prefix.' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_USER:        # This allows to configure the redis user that is configured for the external redis server for authentication. ⚠️ The internal redis container does not support this variable!' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT: 6379       # This allows to configure the redis port that is used to connect to redis. ⚠️ The internal redis container does not support this variable!' >> values.yaml
        # Optional additional cluster hosts/ports
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_2:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_2)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_2: 6379     # Optional port for REDIS_HOST_2 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_3:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_3)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_3: 6379     # Optional port for REDIS_HOST_3 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_4:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_4)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_4: 6379     # Optional port for REDIS_HOST_4 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_5:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_5)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_5: 6379     # Optional port for REDIS_HOST_5 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_6:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_6)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_6: 6379     # Optional port for REDIS_HOST_6 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_7:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_7)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_7: 6379     # Optional port for REDIS_HOST_7 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_8:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_8)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_8: 6379     # Optional port for REDIS_HOST_8 (default 6379)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_HOST_9:        # Optional additional redis host for rediscluster mode (use with REDIS_PORT_9)' >> values.yaml
        # shellcheck disable=SC2129
        echo 'REDIS_PORT_9: 6379     # Optional port for REDIS_HOST_9 (default 6379)' >> values.yaml
        echo '# NEXTCLOUD_TRUSTED_CERTIFICATES.REDIS: # This allows to enable TLS connections for Redis. Please configure this further down at the NEXTCLOUD_TRUSTED_CERTIFICATES section.' >> values.yaml
    fi
done

# Additional config
cat << EOL > /tmp/additional.config
          env:
            - name: NC_EAIO_VERSION
              value: "v{{ .Chart.Version }}"
            - name: PHP_MAX_TIME
              value: "{{ .Values.NEXTCLOUD_MAX_TIME }}"
            - name: PHP_MEMORY_LIMIT
              value: "{{ .Values.NEXTCLOUD_MEMORY_LIMIT }}"
            - name: PHP_UPLOAD_LIMIT
              value: "{{ .Values.NEXTCLOUD_UPLOAD_LIMIT }}"
            - name: TZ
              value: "{{ .Values.TIMEZONE }}"
            - name: REDIS_HOST
              value: "{{ .Values.REDIS_HOST }}"
            - name: REDIS_HOST_PASSWORD
              value: "{{ .Values.REDIS_PASSWORD }}"
            - name: REDIS_MODE
              value: "{{ .Values.REDIS_MODE | default "redis" }}"
            - name: REDIS_CONNECT_STRING
              value: "{{- include "build_redis_connect_string" . | nospace }}"
            {{- if .Values.NEXTCLOUD_TRUSTED_CERTIFICATES }}
            {{- if kindIs "map" .Values.NEXTCLOUD_TRUSTED_CERTIFICATES }}
            - name: "LDAPTLS_CACERT"
              value: /var/www/html/data/certificates/ca-bundle.crt
            {{- end }}
            {{- end }}
EOL
# shellcheck disable=SC1083
find ./ -name '*nextcloud-deployment.yaml' -exec sed -i "/^\ \ \ \ \ \ \ \ \ \ name: nextcloud-enterprise-nextcloud/r /tmp/additional.config"  \{} \;

# Additional config
cat << EOL > /tmp/talk-recording.config
            {{- if ne .Values.TALK_HOST "nextcloud-enterprise-talk" }}
            - name: HPB_DOMAIN
              value: "{{ .Values.TALK_HOST }}"
            - name: HPB_PATH
              value: "{{ .Values.TALK_HPB_PATH }}"
            {{- end }}
EOL
# shellcheck disable=SC1083
find ./ -name '*talk-recording-deployment.yaml' -exec sed -i "/\- env:/r /tmp/talk-recording.config"  \{} \;

# Additional config
cat << EOL > /tmp/whiteboard.config
            - name: REDIS_DB_INDEX
              value: "{{ .Values.REDIS_DB_INDEX }}"
            - name: REDIS_USER
              value: "{{ .Values.REDIS_USER }}"
EOL
# shellcheck disable=SC1083
find ./ -name '*whiteboard-deployment.yaml' -exec sed -i "/\- env:/r /tmp/whiteboard.config"  \{} \;

cat << EOL > ./templates/nextcloud-enterprise-autoscaler.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nextcloud-enterprise-nextcloud-horizontal-autoscaler
  namespace: "{{ .Values.NAMESPACE }}"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nextcloud-enterprise-nextcloud
  minReplicas: 1
  maxReplicas: {{ .Values.MAX_REPLICAS | default 10 }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 60

---

{{- if eq .Values.IMAGINARY_ENABLED "yes" }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nextcloud-enterprise-imaginary-horizontal-autoscaler
  namespace: "{{ .Values.NAMESPACE }}"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nextcloud-enterprise-imaginary
  minReplicas: 1
  maxReplicas: {{ .Values.MAX_REPLICAS | default 10 }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 60
{{- end }}

---

{{- if eq .Values.WHITEBOARD_ENABLED "yes" }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nextcloud-enterprise-whiteboard-horizontal-autoscaler
  namespace: "{{ .Values.NAMESPACE }}"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nextcloud-enterprise-whiteboard
  minReplicas: 1
  maxReplicas: {{ .Values.MAX_REPLICAS | default 10 }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 60
{{- end }}

---

apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nextcloud-enterprise-notify-push-horizontal-autoscaler
  namespace: "{{ .Values.NAMESPACE }}"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nextcloud-enterprise-notify-push
  minReplicas: 1
  maxReplicas: {{ .Values.MAX_REPLICAS | default 10 }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 60

---

{{- if eq .Values.VPA_ENABLED "yes" }}
EOL

SERVICES=""
DEPLOYMENTS="$(find ./ -name "*-deployment.yaml" | sort)"
mapfile -t DEPLOYMENTS <<< "$DEPLOYMENTS"
for deployment in "${DEPLOYMENTS[@]}"; do
    if grep -q claimName "$deployment"; then
        CLAIM_NAMES=""
        CLAIM_NAMES="$(grep claimName "$deployment" | grep -oP "nextcloud-enterprise-.*")"
        mapfile -t CLAIM_NAMES <<< "$CLAIM_NAMES"
        for claimname in "${CLAIM_NAMES[@]}"; do
            cat << EOL > /tmp/claim.config
          {{- if (and .Values.NFS_SERVER (not (eq (.Values.USE_PVS | default "no") "yes"))) }}
          nfs:
            server: {{ .Values.NFS_SERVER }}
            path: "{{ .Values.NFS_PREFIX }}/$claimname"
          {{- else if .Values.HOST_PATH }}
          hostPath:
            path: {{ .Values.HOST_PATH }}/$claimname
            type: Directory
          {{- else }}
EOL
            sed -i "/^        - name: $claimname$/r /tmp/claim.config" "$deployment"
            sed -i "/^.*claimName: $claimname$/a\ \ \ \ \ \ \ \ \ \ {{- end }}" "$deployment"
        done
    fi
    SERVICES+="$(grep 'io.kompose.service:' "$deployment" | head -1 | sed 's|.*io.kompose.service: ||'),"
    if head -1 "$deployment" | grep -q ".Values"; then
        head -1 "$deployment" >> ./templates/nextcloud-enterprise-autoscaler.yaml
        ADD_END=1
    else
        ADD_END=0
    fi
    deployment="$(echo "$deployment" | sed 's|^.*/nextcloud-enterprise-||;s|-deployment.yaml||')"
    cat << EOL >> ./templates/nextcloud-enterprise-autoscaler.yaml

apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: nextcloud-enterprise-$deployment-vertical-autoscaler
  namespace: "{{ .Values.NAMESPACE }}"
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       nextcloud-enterprise-$deployment
  updatePolicy:
    updateMode: "Initial"

---
EOL
    # Resources
    RESOURCE_NAME="$(echo "$deployment" | sed 's|-|_|g' | tr '[:lower:]' '[:upper:]')_RESOURCES"
    echo "$RESOURCE_NAME:        # This is an array key and can be used to configure resources. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-requests-and-limits-of-pod-and-container" >> /tmp/resource.values
    cat << RESOURCE > /tmp/resource.config
          {{- if .Values.$RESOURCE_NAME }}
          resources:
            {{- toYaml .Values.$RESOURCE_NAME | nindent 12 }}
          {{- end }}
RESOURCE
    if [ "$RESOURCE_NAME" != "COLLABORA_RESOURCES" ]; then
        sed -i "/^.*image:.*/r /tmp/resource.config" "./templates/nextcloud-enterprise-$deployment-deployment.yaml"
    else
        sed -i "/^.*args:.*/r /tmp/resource.config" "./templates/nextcloud-enterprise-$deployment-deployment.yaml"
    fi

    # Annotations and labels
    ANNOTATIONS_AND_LABELS_NAME="$(echo "$deployment" | sed 's|-|_|g' | tr '[:lower:]' '[:upper:]')_ADDITIONAL_ANNOTATIONS_AND_LABELS"
    echo "$ANNOTATIONS_AND_LABELS_NAME:        # This is an array key and can be used to configure annotations and limits. See the Portal article https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/Annotations-and-labels or the local article at '../docs/Annotations and labels.md'" >> /tmp/annoations_and_labels.values
    cat << ANNOTATIONS > /tmp/annotations.config
        {{- if .Values.$ANNOTATIONS_AND_LABELS_NAME }}
        {{- if .Values.$ANNOTATIONS_AND_LABELS_NAME.annotations }}
        {{- toYaml .Values.$ANNOTATIONS_AND_LABELS_NAME.annotations | nindent 8 }}
        {{- end }}
        {{- end }}
        com.nextcloud.enterprise-aio.version: "v{{ .Chart.Version }}"
ANNOTATIONS
    sed -i "/^      annotations:/r /tmp/annotations.config" "./templates/nextcloud-enterprise-$deployment-deployment.yaml"
    cat << LABELS > /tmp/labels.config
        {{- if .Values.$ANNOTATIONS_AND_LABELS_NAME }}
        {{- if .Values.$ANNOTATIONS_AND_LABELS_NAME.labels }}
        {{- toYaml .Values.$ANNOTATIONS_AND_LABELS_NAME.labels | nindent 8 }}
        {{- end }}
        {{- end }}
LABELS
    sed -i "/^      labels:/r /tmp/labels.config" "./templates/nextcloud-enterprise-$deployment-deployment.yaml"

    if [ "$ADD_END" = 1 ]; then
        echo "{{- end }}" >> ./templates/nextcloud-enterprise-autoscaler.yaml
        echo "" >> ./templates/nextcloud-enterprise-autoscaler.yaml
    fi
done

# shellcheck disable=SC2001
SERVICES="$(echo "$SERVICES" | sed 's|,$||')"

cat << EOL >> ./templates/nextcloud-enterprise-autoscaler.yaml
{{- end }}
EOL

# Allow to add volume that contains the enterprise archive
# shellcheck disable=SC1083
find ./ -name '*nextcloud-management-deployment.yaml' -exec sed -i '$d' \{} \;
cat << EOL > /tmp/archive-volume-claim.config
          {{- end }}
        {{- if .Values.ARCHIVES_PVC_NAME }}
        - name: nextcloud-enterprise-nextcloud-archive
          {{- if (and .Values.NFS_SERVER (not (eq (.Values.USE_PVS | default "no") "yes"))) }}
          nfs:
            server: {{ .Values.NFS_SERVER }}
            path: "{{ .Values.NFS_PREFIX }}/{{ .Values.ARCHIVES_PVC_NAME }}"
          {{- else if .Values.HOST_PATH }}
          hostPath:
            path: {{ .Values.HOST_PATH }}/{{ .Values.ARCHIVES_PVC_NAME }}
            type: Directory
          {{- else }}
          persistentVolumeClaim:
            claimName: {{ .Values.ARCHIVES_PVC_NAME }}
          {{- end }}
        {{- end }}
EOL
# shellcheck disable=SC1083
find ./ -name '*nextcloud-management-deployment.yaml' -exec sed -i "/claimName: nextcloud-enterprise-nextcloud-data/r /tmp/archive-volume-claim.config"  \{} \;
# shellcheck disable=SC1083
find ./ -name "*persistentvolumeclaim.yaml" -exec sed -i "1i\\{{- if (or (eq (.Values.USE_PVS | default \"no\") \"yes\") (not (or .Values.NFS_SERVER .Values.HOST_PATH))) }}" \{} \; 
# shellcheck disable=SC1083
find ./ -name "*persistentvolumeclaim.yaml" -exec sed -i "$ a {{- end }}" \{} \; 

# Inject configurable labels into PVC metadata (useful for backup tools e.g. velero, k8up)
cat << 'LABELS' > /tmp/pvc-labels.config
    {{- if .Values.PVC_LABELS }}
    {{- toYaml .Values.PVC_LABELS | nindent 4 }}
    {{- end }}
LABELS
# shellcheck disable=SC1083
find ./ -name "*persistentvolumeclaim.yaml" -not -name "*nextcloud-data*" -exec sed -i '/    io\.kompose\.service: nextcloud-enterprise-/r /tmp/pvc-labels.config' {} \;

cat << 'LABELS' > /tmp/pvc-data-labels.config
    {{- if and .Values.STORAGE_CLASS_DATA .Values.PVC_LABELS_DATA }}
    {{- toYaml .Values.PVC_LABELS_DATA | nindent 4 }}
    {{- else if .Values.PVC_LABELS }}
    {{- toYaml .Values.PVC_LABELS | nindent 4 }}
    {{- end }}
LABELS
# shellcheck disable=SC1083
sed -i '/    io\.kompose\.service: nextcloud-enterprise-/r /tmp/pvc-data-labels.config' ./templates/nextcloud-enterprise-nextcloud-data-persistentvolumeclaim.yaml

cat << EOL > /tmp/archive-volume-mountpoint.config
            {{- if .Values.ARCHIVES_PVC_NAME }}
            - mountPath: /mnt/archive
              name: nextcloud-enterprise-nextcloud-archive
            {{- end }}
EOL
# shellcheck disable=SC1083
find ./ -name '*nextcloud-management-deployment.yaml' -exec sed -i "/^\ \ \ \ \ \ \ \ \ \ \ \ \ \ name: nextcloud-enterprise-nextcloud-data/r /tmp/archive-volume-mountpoint.config"  \{} \;

VOLUMES="$(find ./ -name "*-persistentvolumeclaim.yaml" | sort)"
mapfile -t VOLUMES <<< "$VOLUMES"
for volume in "${VOLUMES[@]}"; do
    if grep -q "^  name:" "$volume"; then
        name="$(grep '^  name:' "$volume" | sed 's|  name: ||')"
        storage="$(grep 'storage:' "$volume")"
        access_mode="$(grep -oP 'ReadWrite.*' "$volume")"
        if ! echo "$volume" | grep -q "nextcloud-enterprise-nextcloud-data-persistentvolumeclaim"; then
            cat << EOL > /tmp/volume.config
  {{- if eq (.Values.USE_PVS | default "no") "yes" }}
  volumeName: "$name-{{ .Values.NAMESPACE }}"
  {{- end }}
{{- if eq (.Values.USE_PVS | default "no") "yes" }}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: "$name-{{ .Values.NAMESPACE }}"
  {{- if .Values.PVC_LABELS }}
  labels:
    {{- toYaml .Values.PVC_LABELS | nindent 4 }}
  {{- end }}
spec:
  storageClassName: {{ .Values.STORAGE_CLASS }}
  capacity:
$storage
  accessModes:
    - $access_mode
  nfs:
    path: "{{ .Values.NFS_PREFIX }}/$name"
    server: "{{ .Values.NFS_SERVER }}"
{{- end }}
EOL
      else
          cat << EOL > /tmp/volume.config
  {{- if eq (.Values.USE_PVS | default "no") "yes" }}
  volumeName: "$name-{{ .Values.NAMESPACE }}"
  {{- end }}
{{- if eq (.Values.USE_PVS | default "no") "yes" }}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: "$name-{{ .Values.NAMESPACE }}"
  {{- if and .Values.STORAGE_CLASS_DATA .Values.PVC_LABELS_DATA }}
  labels:
    {{- toYaml .Values.PVC_LABELS_DATA | nindent 4 }}
  {{- else if .Values.PVC_LABELS }}
  labels:
    {{- toYaml .Values.PVC_LABELS | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.STORAGE_CLASS_DATA }}
  storageClassName: {{ .Values.STORAGE_CLASS_DATA }}
  {{- else if .Values.STORAGE_CLASS }}
  storageClassName: {{ .Values.STORAGE_CLASS }}
  {{- end }}
  capacity:
$storage
  accessModes:
    - $access_mode
  nfs:
    path: "{{ .Values.NFS_PREFIX }}/$name"
    server: "{{ .Values.NFS_SERVER }}"
{{- end }}
EOL
      fi
      sed -i "/storage:.*/r /tmp/volume.config" "$volume"
    fi
done

# shellcheck disable=SC1083
sed -i '/SMTP_PASSWORD/d' ./templates/*nextcloud-management-deployment.yaml
sed -i 's/^SMTP_PASSWORD.*/SMTP_PASSWORD:          # (empty by default): The password for the authentication. This needs to be a unique and good password or a secret name if you enable USE_SECRETS at the top of the file./' values.yaml

# Additional config
cat << EOL > /tmp/additional.config
            - name: NC_EAIO_VERSION
              value: "v{{ .Chart.Version }}"
            - name: DATABASE_TYPE
              value: "{{ .Values.DATABASE_TYPE }}"
            - name: DISABLE_BRUTEFORCE_PROTECTION
              value: "{{ .Values.DISABLE_BRUTEFORCE_PROTECTION }}"
            - name: NEXTCLOUD_SKIP_DATABASE_OPTIMIZATION
              value: "{{ .Values.NEXTCLOUD_SKIP_DATABASE_OPTIMIZATION }}"
            - name: ENTERPRISE_ARCHIVE_URL
              value: "{{ .Values.ENTERPRISE_ARCHIVE_URL }}"
            - name: TALK_HOST
              value: "{{ .Values.TALK_HOST }}"
            - name: HPB_PATH
              value: "{{ .Values.TALK_HPB_PATH }}"
            - name: http_proxy
              value: "{{ .Values.HTTP_PROXY }}"
            - name: HTTP_PROXY
              value: "{{ .Values.HTTP_PROXY }}"
            - name: HTTPS_PROXY
              value: "{{ .Values.HTTP_PROXY }}"
            - name: NO_PROXY
              value: "$SERVICES{{ if .Values.PROXY_EXCLUDE }},{{ .Values.PROXY_EXCLUDE }}{{ end }}"
            - name: REDIS_MODE
              value: "{{ .Values.REDIS_MODE | default "redis" }}"
            - name: REDIS_HOST_PASSWORD
              value: "{{ .Values.REDIS_PASSWORD }}"
            - name: REDIS_CONNECT_STRING
              value: "{{- include "build_redis_connect_string" . | nospace }}"
            - name: REDIS_DB_INDEX
              value: "{{ .Values.REDIS_DB_INDEX }}"
            - name: REDIS_PREFIX
              value: "{{ .Values.REDIS_PREFIX }}"
            {{- if .Values.REDIS_USER }}
            - name: REDIS_USER_AUTH
              value: "&auth[]={{ .Values.REDIS_USER }}"
            {{- end }}
            - name: REDIS_HOST_2
              value: "{{ .Values.REDIS_HOST_2 }}"
            - name: REDIS_PORT_2
              value: "{{ .Values.REDIS_PORT_2 }}"
            - name: REDIS_HOST_3
              value: "{{ .Values.REDIS_HOST_3 }}"
            - name: REDIS_PORT_3
              value: "{{ .Values.REDIS_PORT_3 }}"
            - name: REDIS_HOST_4
              value: "{{ .Values.REDIS_HOST_4 }}"
            - name: REDIS_PORT_4
              value: "{{ .Values.REDIS_PORT_4 }}"
            - name: REDIS_HOST_5
              value: "{{ .Values.REDIS_HOST_5 }}"
            - name: REDIS_PORT_5
              value: "{{ .Values.REDIS_PORT_5 }}"
            - name: REDIS_HOST_6
              value: "{{ .Values.REDIS_HOST_6 }}"
            - name: REDIS_PORT_6
              value: "{{ .Values.REDIS_PORT_6 }}"
            - name: REDIS_HOST_7
              value: "{{ .Values.REDIS_HOST_7 }}"
            - name: REDIS_PORT_7
              value: "{{ .Values.REDIS_PORT_7 }}"
            - name: REDIS_HOST_8
              value: "{{ .Values.REDIS_HOST_8 }}"
            - name: REDIS_PORT_8
              value: "{{ .Values.REDIS_PORT_8 }}"
            - name: REDIS_HOST_9
              value: "{{ .Values.REDIS_HOST_9 }}"
            - name: REDIS_PORT_9
              value: "{{ .Values.REDIS_PORT_9 }}"
            - name: TURN_DOMAIN
              value: "{{ .Values.TURN_DOMAIN }}"
            - name: CLAMAV_BLOCKLISTED_DIRECTORIES
              value: "{{ .Values.CLAMAV_BLOCKLISTED_DIRECTORIES }}"
            - name: NEXTCLOUD_LOG_TYPE
              value: "{{ .Values.NEXTCLOUD_LOG_TYPE }}"
            - name: OBJECTSTORE_S3_BUCKET
              value: "{{ .Values.OBJECTSTORE_S3_BUCKET }}"
            - name: OBJECTSTORE_S3_NUM_BUCKETS
              value: "{{ .Values.OBJECTSTORE_S3_NUM_BUCKETS }}"
            - name: OBJECTSTORE_S3_REQUEST_CHECKSUM_VALIDATION
              value: "{{ .Values.OBJECTSTORE_S3_REQUEST_CHECKSUM_VALIDATION }}"
            - name: OBJECTSTORE_S3_RESPONSE_CHECKSUM_VALIDATION
              value: "{{ .Values.OBJECTSTORE_S3_RESPONSE_CHECKSUM_VALIDATION }}"
            - name: OBJECTSTORE_S3_REGION
              value: "{{ .Values.OBJECTSTORE_S3_REGION }}"
            - name: OBJECTSTORE_S3_HOST
              value: "{{ .Values.OBJECTSTORE_S3_HOST }}"
            - name: OBJECTSTORE_S3_PORT
              value: "{{ .Values.OBJECTSTORE_S3_PORT }}"
            - name: OBJECTSTORE_S3_KEY
              {{- if and (eq (.Values.USE_SECRETS | default "no") "yes") (.Values.OBJECTSTORE_S3_KEY) }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.OBJECTSTORE_S3_KEY }} 
                  key:  {{ .Values.OBJECTSTORE_S3_KEY }} 
              {{- else }}
              value: "{{ .Values.OBJECTSTORE_S3_KEY }}"
              {{- end }}
            - name: OBJECTSTORE_S3_SECRET
              {{- if and (eq (.Values.USE_SECRETS | default "no") "yes") (.Values.OBJECTSTORE_S3_SECRET) }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.OBJECTSTORE_S3_SECRET }} 
                  key:  {{ .Values.OBJECTSTORE_S3_SECRET }} 
              {{- else }}
              value: "{{ .Values.OBJECTSTORE_S3_SECRET }}"
              {{- end }}
            - name: OBJECTSTORE_S3_STORAGE_CLASS
              value: "{{ .Values.OBJECTSTORE_S3_STORAGE_CLASS }}"
            - name: OBJECTSTORE_S3_SSL
              value: "{{ .Values.OBJECTSTORE_S3_SSL }}"
            - name: OBJECTSTORE_S3_USEPATH_STYLE
              value: "{{ .Values.OBJECTSTORE_S3_USEPATH_STYLE }}"
            - name: OBJECTSTORE_S3_LEGACYAUTH
              value: "{{ .Values.OBJECTSTORE_S3_LEGACYAUTH }}"
            - name: OBJECTSTORE_S3_OBJECT_PREFIX
              value: "{{ .Values.OBJECTSTORE_S3_OBJECT_PREFIX }}"
            - name: OBJECTSTORE_S3_MULTIBUCKET
              value: "{{ .Values.OBJECTSTORE_S3_MULTIBUCKET }}"
            - name: OBJECTSTORE_S3_AUTOCREATE
              value: "{{ .Values.OBJECTSTORE_S3_AUTOCREATE }}"
            - name: OBJECTSTORE_S3_SSE_C_KEY
              {{- if and (eq (.Values.USE_SECRETS | default "no") "yes") (.Values.OBJECTSTORE_S3_SSE_C_KEY) }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.OBJECTSTORE_S3_SSE_C_KEY }} 
                  key:  {{ .Values.OBJECTSTORE_S3_SSE_C_KEY }} 
              {{- else }}
              value: "{{ .Values.OBJECTSTORE_S3_SSE_C_KEY }}"
              {{- end }}
            - name: SMTP_PASSWORD
              {{- if and (eq (.Values.USE_SECRETS | default "no") "yes") (.Values.SMTP_PASSWORD) }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.SMTP_PASSWORD }} 
                  key:  {{ .Values.SMTP_PASSWORD }} 
              {{- else }}
              value: "{{ .Values.SMTP_PASSWORD }}"
              {{- end }}
            - name: AIRGAPPED
              value: "{{ .Values.AIRGAPPED }}"
            - name: NEXTCLOUD_APP_STORE_URL
              value: "{{ .Values.NEXTCLOUD_APP_STORE_URL }}"
            {{- if .Values.NEXTCLOUD_TRUSTED_CERTIFICATES }}
            {{- range \$name, \$value := .Values.NEXTCLOUD_TRUSTED_CERTIFICATES }}
            - name: "NEXTCLOUD_TRUSTED_CERTIFICATES_{{ \$name }}"
              value: | {{ \$value | nindent 16 }}
            {{- end }}
            {{- if kindIs "map" .Values.NEXTCLOUD_TRUSTED_CERTIFICATES }}
            - name: "LDAPTLS_CACERT"
              value: /var/www/html/data/certificates/ca-bundle.crt
            {{- end }}
            {{- end }}
            - name: NEXTCLOUD_PERSIST_DATABASE_CONNECTIONS
              value: "{{ .Values.NEXTCLOUD_PERSIST_DATABASE_CONNECTIONS }}"
EOL
# shellcheck disable=SC1083
find ./ -name '*nextcloud-management-deployment.yaml' -exec sed -i "/^.*\- env:/r /tmp/additional.config"  \{} \;

# Secret handling
sed  -i "1i USE_SECRETS: \"no\"         # Setting this to \"yes\" allows to use secrets instead of plain text env variables. The secrets need to be created beforehand manually in the format name: \$SECRET_NAME, key: \$SECRET_NAME. See https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/How-to-use-secrets or the local article at '../docs/How to use secrets.md'" values.yaml
SECRETS="$(grep "TODO! This needs to be a unique and good password!" values.yaml | grep -oP '^[A-Z_]+')"
sed -i "s|TODO! This needs to be a unique and good password!|TODO! This needs to be a unique and good password or a secret name if you enable USE_SECRETS at the top of the file.|" values.yaml
sed -i "s|TODO! This is the password of the initially created Nextcloud admin with username admin.|TODO! This is the password or a secret name if you enable USE_SECRETS at the top of the file. It is the password of the initially created Nextcloud admin with username admin.|" values.yaml
mapfile -t SECRETS <<< "$SECRETS"
SECRETS+=(NEXTCLOUD_PASSWORD)
for secret in "${SECRETS[@]}"; do
  # Additional config
  cat << EOL > /tmp/secret.config
              {{- if eq (.Values.USE_SECRETS | default "no") "yes" }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.$secret }} 
                  key:  {{ .Values.$secret }} 
              {{- else }}
              value: {{ .Values.$secret | quote }}
              {{- end }}
EOL
  # shellcheck disable=SC1083
  find ./ -name "*deployment.yaml" -exec sed -i "s/value: [\{\"]\+ .Values.$secret [\}\"]\+/SECRET_REPLACEMENT_$secret/g" \{} \; 
  # shellcheck disable=SC1083
  find ./ -name '*deployment.yaml' -exec sed -i "/SECRET_REPLACEMENT_$secret/r /tmp/secret.config" \{} \; 
  # shellcheck disable=SC1083
  find ./ -name "*deployment.yaml" -exec sed -i "/SECRET_REPLACEMENT_$secret/d" \{} \; 
done

NEXTCLOUD_UGID=33
REDIS_UGID=999
POSTGRES_UGID=999
TALK_RECORDING_UGID=122
IMAGINARY_UGID=65534
CLAMAV_UGID=100
TALK_UGID=1000
WHITEBOARD_UGID=65534

# shellcheck disable=SC2129
cat << VALUES >> values.yaml
NEXTCLOUD_LOG_TYPE: "file"          # Setting this to "errorlog" allows to send all logs to the container logs which centralises logging. However this will disable the logreader app inside Nextcloud.
NEXTCLOUD_SKIP_DATABASE_OPTIMIZATION: "no"        # Setting this to "yes" allows to skip the database optimizations after updating the Nextcloud archive which reduces the downtime. However database optimization needs to be run manually then after the update is gone through.
NEXTCLOUD_APP_STORE_URL:          # This allows to configure the Nextcloud App store URL inside Nextcloud. Defaults to 'https://apps.nextcloud.com/api/v1'. You can disable the app store feature completely by setting the string to 'no' ⚠️ Please note that the automatic downloading of the integrations app for additional components like whiteboard, talk, collabora, onlyoffice, notify-push and co will not work in that case anymore. See https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/values.yaml-ARCHIVES_PVC_NAME-for-local-archives for that case.
NEXTCLOUD_PERSIST_DATABASE_CONNECTIONS: "no"          #  Setting this to "yes" allows to enable persistent db connections inside Nextcloud and might improve the performance. ⚠️ However, enabling database persistent connection must be done carefully as if misconfigured it can overload the database, with too many php-fpm children processes in regard to the number of connections allowed on the database side. 
COLLABORA_HOST: nextcloud-enterprise-collabora        # Setting this to something else than 'nextcloud-enterprise-collabora' will allow you to use an external service.
CLAMAV_BLOCKLISTED_DIRECTORIES:          # This allows to configure blocklisted directories in files antivirus. It expects a string like "['dont-scan', 'donotscan', 'second-dir']"
TALK_HOST: nextcloud-enterprise-talk        # Setting this to something else than 'nextcloud-enterprise-talk' will allow you to use an external service.
TALK_HPB_PATH: /standalone-signaling/          # If TALK_HOST is set to something else than 'nextcloud-enterprise-talk' this allows to set the path to the signaling server in TALK_HOST.
# SIGNALING_SECRET:           # This allows to set the signaling password which is getting set at the very top of this values.yaml file.
# TALK_INTERNAL_SECRET:           # This allows to set the internal signaling password which is getting set at the very top of this values.yaml file.
TURN_DOMAIN:         # This allows to adjust the domain that will be configured as stun/turn domain inside Nextcloud
FULLTEXTSEARCH_HOST: nextcloud-enterprise-fulltextsearch        # Setting this to something else than 'nextcloud-enterprise-fulltextsearch' will allow you to use an external service.
FULLTEXTSEARCH_PROTOCOL: http          # This allows to adjust the protocol that will be used to connect Nextcloud to the elasticsearch service. ⚠️ Please note that the built-in fulltextsearch deployment only supports the default "http"!
FULLTEXTSEARCH_PORT: 9200          # This allows to adjust the port that will be used to connect Nextcloud to the elasticsearch service. ⚠️ Please note that the built-in fulltextsearch deployment only supports the default port 9200!
FULLTEXTSEARCH_USER: elastic          # This allwows to adjust the fulltextsearch user that will be used to connect Nextcloud to the Elasticsearch instance ⚠️ Please note that the built-in fulltextsearch deployment only supports the default user 'elastic'!
# FULLTEXTSEARCH_PASSWORD:           # This allows to set the fulltextsearch password which is getting set at the very top of this values.yaml file.
FULLTEXTSEARCH_INDEX: nextcloud-aio          # This allows to adjust the fulltextsearch index that will be used.
ONLYOFFICE_HOST: nextcloud-enterprise-onlyoffice        # Setting this to something else than 'nextcloud-enterprise-onlyoffice' will allow you to use an external service.
# ONLYOFFICE_SECRET:           # This allows to set the Onlyoffice password which is getting set at the very top of this values.yaml file.
VPA_ENABLED: "yes"        # This allows to disable the VerticalPodAutoscaler which is enabled by default by setting it to something else than "yes" (with quotes)
MAX_REPLICAS: &MAX_REPLICAS 10        # This allows to adjust the max replica setting in the HPA. Set it to 1 if you want to disable the HPA.
RPSS_ENABLED: "no"         # By setting this to "yes", you can make the chart compatible with the Restricted Pod Security Standard. ⚠️ Warning: some bundled container like collabora, fulltextseach and onlyoffice are known to not work with RPSS enabled. They need to be disabled in this chart and get provided externally if you need those. See https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#scalable-full-nextcloud-hub-installation
IMAGE_PULL_SECRET:        # This allows to configure a pull secret for all images when used with a private image repository for example. The pull secret needs to be specified for the nginx subchart manually as well if you need this.
ENTERPRISE_ARCHIVE_URL: https://download.nextcloud.com/.customers/server/33.0.5-674acdae/nextcloud-33.0.5-enterprise.zip
HTTP_PROXY:        # This allows set the http proxy value in Nextcloud for outgoing connections
PROXY_EXCLUDE:        # This allows to add a host or a comma-separated list of hosts to the proxy exclude list in Nextcloud
ARCHIVES_PVC_NAME:        # Instead of downloading the archive from ENTERPRISE_ARCHIVE_URL, you can set this variable which will mount the given PVC name into the management container. It needs to contain the enterprise-archive as zip file in the root. The file needs to be named like this: 'nextcloud-28.0.4-enterprise.zip' like it is originally. You need to specify the name of the archive by using the ENTERPRISE_ARCHIVE_URL variable. Make sure to create and populate the volume before starting this helm chart as it will otherwise fail to. Also make sure that the linux permissions are set correctly and every user can read the file.
AIRGAPPED:        # Setting this to "yes" (with quotes) will automatically set the values has_internet_connection, updatechecker and has_valid_subscription correctly inside Nextclouds config.php for airgapped environments.
DISABLE_BRUTEFORCE_PROTECTION: "no"         # Setting this to "yes" (with quotes) disables the bruteforce protection and ratelimit protection in Nextcloud. ⚠️⚠️⚠️ Warning: only do this if you are not in control over the network and there is no way the correct ip-address is kept in requests. Usually Adjusting ADDITIONAL_TRUSTED_PROXY is the correct way of fixing this problem!

SERVICE_ACCOUNT: &SERVICE_ACCOUNT "default"          # This allows to set a custom service account for all deployments. ⚠️ The service account must already be existing!
NEXTCLOUD_UGID: &NEXTCLOUD_UGID $NEXTCLOUD_UGID          # This allows to configure the UID and GID that is used for the Nextcloud, Nextcloud-Management, Notify-Push and Apache deployments.
REDIS_UGID: $REDIS_UGID          # This allows to configure the UID and GID that is used for the Redis deployment
POSTGRES_UGID: $POSTGRES_UGID          # This allows to configure the UID and GID that is used for the Database deployment
TALK_RECORDING_UGID: $TALK_RECORDING_UGID          # This allows to configure the UID and GID that is used for the Talk-Recording deployment
IMAGINARY_UGID: $IMAGINARY_UGID          # This allows to configure the UID and GID that is used for the Imaginary deployment
CLAMAV_UGID: $CLAMAV_UGID          # This allows to configure the UID and GID that is used for the ClamAV deployment
TALK_UGID: $TALK_UGID          # This allows to configure the UID and GID that is used for the Talk deployment
WHITEBOARD_UGID: $WHITEBOARD_UGID          # This allows to configure the UID and GID that is used for the Whiteboard deployment

NEXTCLOUD_TRUSTED_CERTIFICATES:          # This allows to configure custom certificates that will be added to Nextcloud's trusted certificate store during runtime. See https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/How-to-add-custom-certificates or the local article at '../docs/How to add custom certificates.md'

VALUES

# shellcheck disable=SC1083
find ./ \( -name '*nextcloud-deployment.yaml' -o -name '*nextcloud-management-deployment.yaml' -o -name '*apache-deployment.yaml' -o -name '*notify-push-deployment.yaml' \) -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.NEXTCLOUD_UGID | default $NEXTCLOUD_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.NEXTCLOUD_UGID | default $NEXTCLOUD_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.NEXTCLOUD_UGID | default $NEXTCLOUD_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*redis-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.REDIS_UGID | default $REDIS_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.REDIS_UGID | default $REDIS_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.REDIS_UGID | default $REDIS_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*database-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.POSTGRES_UGID | default $POSTGRES_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.POSTGRES_UGID | default $POSTGRES_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.POSTGRES_UGID | default $POSTGRES_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*talk-recording-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.TALK_RECORDING_UGID | default $TALK_RECORDING_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.TALK_RECORDING_UGID | default $TALK_RECORDING_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.TALK_RECORDING_UGID | default $TALK_RECORDING_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*imaginary-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.IMAGINARY_UGID | default $IMAGINARY_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.IMAGINARY_UGID | default $IMAGINARY_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.IMAGINARY_UGID | default $IMAGINARY_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*clamav-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.CLAMAV_UGID | default $CLAMAV_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.CLAMAV_UGID | default $CLAMAV_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.CLAMAV_UGID | default $CLAMAV_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*talk-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.TALK_UGID | default $TALK_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.TALK_UGID | default $TALK_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.TALK_UGID | default $TALK_UGID \}\}/"  \{} \;
# shellcheck disable=SC1083
find ./ -name '*whiteboard-deployment.yaml' -exec sed -i "s/fsGroup:.*/fsGroup: \{\{ .Values.WHITEBOARD_UGID | default $WHITEBOARD_UGID \}\}/;s/runAsUser.*/runAsUser: \{\{ .Values.WHITEBOARD_UGID | default $WHITEBOARD_UGID \}\}/;s/runAsGroup.*/runAsGroup: \{\{ .Values.WHITEBOARD_UGID | default $WHITEBOARD_UGID \}\}/"  \{} \;

# shellcheck disable=SC2129
cat /tmp/resource.values >> values.yaml
# shellcheck disable=SC2129
echo "" >> values.yaml
# shellcheck disable=SC2129
cat /tmp/annoations_and_labels.values >> values.yaml

# shellcheck disable=SC2129
cat << VALUES >> values.yaml

PVC_LABELS:        # Optional map of extra labels to add to all PVCs and PVs that use STORAGE_CLASS. Useful for backup tools (e.g. velero, k8up). Example: {backup.velero.io/include-resources: pvc}
PVC_LABELS_DATA:        # Optional map of extra labels for the Nextcloud data PVC/PV when STORAGE_CLASS_DATA is set. Falls back to PVC_LABELS if not configured.
USE_PVS: "no"         # Setting this to "yes" (with quotes) allows to enable the usage of PVs and use NFS at the same time inside these. Please note that currently only NFS for these is supported, not local storage. ⚠️ Make sure to also set STORAGE_CLASS to a custom class that does not exist on your cluster yet.
NFS_SERVER: &NFS_SERVER        # This allows to set a domain for a nfs server (add the domain behind &NFS_SERVER) if you plan to use that instead of persistentvolumeclaims. The subfolders need to be created on the nfs server manually beforehand. Make also sure to modify the extraVolumes block in the nginx subchart config at the bottom of this file.
NFS_PREFIX:          # This allows to set a prefix for the nfs server to store multiple different instance on one NFS server. It needs to have a leading slash and not have a trailing slash. Make also sure to modify the extraVolumes block in the nginx subchart config at the bottom of this file.
HOST_PATH:         # This allows to configure a host path if you plan to use that instead of persistentvolumeclaims or nfs server. The subfolders need to be created manually beforehand. Make also sure to modify the extraVolumes block in the nginx subchart config at the bottom of this file.
OBJECTSTORE_S3_BUCKET:        # The name of the bucket that Nextcloud should store the data in
OBJECTSTORE_S3_REGION:        # The region that the S3 bucket resides in
OBJECTSTORE_S3_HOST:        # The hostname of the object storage server
OBJECTSTORE_S3_PORT:        # The port that the object storage server is being served over
OBJECTSTORE_S3_KEY:        # AWS style access key. This needs to be a unique and good password or a secret name if you enable USE_SECRETS at the top of the file.
OBJECTSTORE_S3_SECRET:        # AWS style secret access key. This needs to be a unique and good password or a secret name if you enable USE_SECRETS at the top of the file.
OBJECTSTORE_S3_STORAGE_CLASS:        # The storage class to use when adding objects to the bucket
OBJECTSTORE_S3_SSL:        # (default: true): Whether or not SSL/TLS should be used to communicate with object storage server
OBJECTSTORE_S3_USEPATH_STYLE:        # (default: false): Not required for AWS S3
OBJECTSTORE_S3_LEGACYAUTH:        # (default: false): Not required for AWS S3
OBJECTSTORE_S3_OBJECT_PREFIX:        # (default: urn:oid:): Prefix to prepend to the fileid
OBJECTSTORE_S3_MULTIBUCKET:          # (default: false): Allow to use the multibucket feature
OBJECTSTORE_S3_NUM_BUCKETS:        # (default: 64): The total amount of buckets that Nextcloud should store the data in
OBJECTSTORE_S3_REQUEST_CHECKSUM_VALIDATION:          # (default: 'when_required'. Alternatively possible is 'when_supported'): Data Integrity Protections for Amazon S3 (https://docs.aws.amazon.com/sdkref/latest/guide/feature-dataintegrity.html)
OBJECTSTORE_S3_RESPONSE_CHECKSUM_VALIDATION:          # (default: 'when_required'. Alternatively possible is 'when_supported'): Data Integrity Protections for Amazon S3 (https://docs.aws.amazon.com/sdkref/latest/guide/feature-dataintegrity.html)
OBJECTSTORE_S3_AUTOCREATE:        # (default: true): Create the container if it does not exist
OBJECTSTORE_S3_SSE_C_KEY:        # (not set by default): Base64 encoded key with a maximum length of 32 bytes for server side encryption (SSE-C). This needs to be a unique and good password or a secret name if you enable USE_SECRETS at the top of the file.

NGINX_ENABLE_HSTS: "yes"        # Setting this to "yes" (with quotes) enables the hsts header in the included nginx config. You can set it to something else to disable it, e.g. if you are using nginx-ingress and want to use the default hsts that it sends
INGRESS_ENABLED: "no"           # Settings this to "yes" (with quotes) enables the ingress which will point to APACHE_HOST on port APACHE_PORT
INGRESS_CLUSTER_ISSUER: "letsencrypt-prod"        # This allows to set the cluster issuer that will be used for the ingress
INGRESS_CLASS_NAME: "nginx"            # This allows to set the ingress class name that will be used for the ingress
OPENSHIFT_ROUTE_ENABLED: "no"          # Setting this to "yes" (with quotes) enables an OpenShift Route (route.openshift.io/v1) instead of a standard Kubernetes Ingress. Use this on OpenShift clusters with the default HAProxy-based ingress router. ⚠️ Do not set both INGRESS_ENABLED and OPENSHIFT_ROUTE_ENABLED to "yes" at the same time!

# Optional sub-chart to replace the default apache with a scalable nginx server.
# It requires the NGINX Ingress Controller (or alternatively ingress-nginx) and cert-manager for automatic TLS.
# Otherwise, provide a custom external TLS reverse proxy and change service.type to "LoadBalancer".
#
# Requirements:
#   - Set nginx.enable to true
#   - Set APACHE_HOST to "nextcloud-enterprise-nginx" (keep the '&APACHE_HOST' before the actual value)
#   - Ensure that NAMESPACE contains the &NAMESPACE anchor to link both values
#     or adjust it manually for the sub-chart
#     ('NAMESPACE' and 'nginx.namespaceOverride' should match)
#
# For TLS via NGINX Ingress Controller (or ingress-nginx) and cert-manager:
#   - Set INGRESS_ENABLED to "yes"
#
# Please refer to the chart's readme for more information on all values:
# https://github.com/bitnami/charts/tree/main/bitnami/nginx/
nginx:
  enabled: false # Set this to true in order to enable the subchart

  image:
    registry: ghcr.io # Set this if you use a custom registry (default: ghcr.io)
    repository: nextcloud-releases/nce-nginx # Set this if you use a custom repository (default: nextcloud-releases/nce-nginx)
    tag: "$DOCKER_TAG" # This is the date tag used. Should be updated regularly. See https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#how-to-update
    # pullSecrets: # Uncomment if you need to use a pull secret for the subchart
    #   - \$IMAGE_PULL_SECRET # Adjust the string to the secret name that you want to use

  # The following global config is needed due to changing the repo to the bitnamisecure one.
  global:
    security:
      allowInsecureImages: true

  service:
    type: ClusterIP  # Should be "LoadBalancer" if no ingress is used

  extraVolumes:
    - name: nextcloud-enterprise-nextcloud
# { if not NFS_SERVER and not HOST_PATH }
      persistentVolumeClaim: # Comment if you plan to use NFS_SERVER
        claimName: nextcloud-enterprise-nextcloud # Comment if you plan to use NFS_SERVER
# { else if not HOST_PATH }
      # nfs:
      #   server: *NFS_SERVER # Should match NFS_SERVER
      #   path: \$NFS_PREFIX/nextcloud-enterprise-nextcloud # \$NFS_PREFIX needs to be adjusted to match the configured value.
# { else }
      # hostPath:
      #   path: \$HOST_PATH/nextcloud-enterprise-nextcloud # HOST_PATH needs to be manually edited and set here as well
      #   type: Directory
# { end }

  resourcesPreset: medium # You can adjust the resources with this string. See https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl.

  podLabels:
    io.kompose.service: nextcloud-enterprise-nginx # This is required for the system to work correctly, so do not modify this!
    # additional-label1: value1 # See https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/Annotations-and-labels or the local article at '../docs/Annotations and labels.md'

  # podAnnotations: # Uncomment this if you need to add annotations to the nginx pod. See https://portal.nextcloud.com/article/Scalability/Enterprise-AIO/Annotations-and-labels or the local article at '../docs/Annotations and labels.md'
    # additional-anntotation1: value1

### Values below should not be changed unless you know what you are doing! ###

  fullnameOverride: *APACHE_HOST
  namespaceOverride: *NAMESPACE

  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: *MAX_REPLICAS 
    targetCPU: 60
    targetMemory: 60

  containerSecurityContext:
    runAsUser: *NEXTCLOUD_UGID
    runAsGroup: *NEXTCLOUD_UGID

  serviceAccount:
    create: false
    name: *SERVICE_ACCOUNT

  podSecurityContext:
    fsGroupChangePolicy: OnRootMismatch

  containerPorts:
    http: 8080
    https: null

  extraVolumeMounts:
    - name: nextcloud-enterprise-nextcloud
      mountPath: /var/www/html

  existingServerBlockConfigmap: nextcloud-enterprise-nginx-configmap

  livenessProbe:
    enabled: false
  readinessProbe:
    enabled: false

  customReadinessProbe:
    tcpSocket:
      port: 8080
    initialDelaySeconds: 15
    periodSeconds: 10
  customLivenessProbe:
    tcpSocket:
      port: 8080
    initialDelaySeconds: 15
    periodSeconds: 10

VALUES

sed -i "/^.*- nextcloud-enterprise-apache$/a\ \ \ \ \ \ \ \ \ \ - nextcloud-enterprise-nginx" ./templates/nextcloud-enterprise-networkpolicy.yaml

cat << EOL > ./templates/nextcloud-enterprise-nginx-configmap.yaml
{{- if and .Values.nginx.enabled (eq .Values.nginx.existingServerBlockConfigmap "nextcloud-enterprise-nginx-configmap") }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-enterprise-nginx-configmap
  namespace: "{{ .Values.NAMESPACE }}"
data:
  nextcloud.conf: |
EOL

curl -fsSL https://raw.githubusercontent.com/nextcloud/documentation/master/admin_manual/installation/nginx-root.conf.sample -o /tmp/nginx.conf
sed -i 's|server 127.0.0.1:9000;|server nextcloud-enterprise-nextcloud:9000;|' /tmp/nginx.conf
sed -i 's|    ssl_cert|    # ssl_cert|' /tmp/nginx.conf
sed -i 's|root /var/www/nextcloud;|root /var/www/html;|' /tmp/nginx.conf
sed -i '/listen \[::\]:443/d' /tmp/nginx.conf
sed -i '/listen \[::\]:80;/d' /tmp/nginx.conf
sed -i '/# listen 443.*;/d' /tmp/nginx.conf
sed -i 's|listen 443.*|listen 8080;|' /tmp/nginx.conf
sed -i 's|listen 80\;$|listen 9000;|' /tmp/nginx.conf
sed -i '/# With NGinx/d' /tmp/nginx.conf
sed -i "s|# http2 on;|http2 on;|" /tmp/nginx.conf
sed -i '/server_name cloud.example.com;/d' /tmp/nginx.conf
sed -i 's|return 301 https:|# return 301 https:|' /tmp/nginx.conf
sed -i 's/client_max_body_size.*/client_max_body_size "{{ .Values.APACHE_MAX_SIZE }}";/' /tmp/nginx.conf
sed -i 's/client_body_timeout.*/client_body_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#proxy_connect_timeout.*/proxy_connect_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#proxy_send_timeout.*/proxy_send_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#proxy_read_timeout .*/proxy_read_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#send_timeout.*/send_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#fastcgi_read_timeout.*/fastcgi_read_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#fastcgi_send_timeout.*/fastcgi_send_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#fastcgi_connect_timeout.*/fastcgi_connect_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
sed -i 's/#keepalive_timeout.*/keepalive_timeout {{ .Values.NEXTCLOUD_MAX_TIME }}s;/' /tmp/nginx.conf
cat << EOL > /tmp/hsts.config
    {{- if eq .Values.NGINX_ENABLE_HSTS "yes" }}
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;
    {{- end }}
EOL
sed -i "/^.*#add_header Strict-Transport-Security.*/r /tmp/hsts.config" /tmp/nginx.conf
cat << EOL > /tmp/nginx.config
    # Config for notify-push
    location ^~ /push/ {
        proxy_pass http://nextcloud-enterprise-notify-push:7867/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    {{- if and (eq .Values.COLLABORA_HOST "nextcloud-enterprise-collabora") (eq .Values.COLLABORA_ENABLED "yes") }}
    # Config for Collabora
    # static files
    location ^~ /browser {
        proxy_pass http://nextcloud-enterprise-collabora:9980;
        proxy_set_header Host \$host;
    }
    # WOPI discovery URL
    location ^~ /hosting/discovery {
        proxy_pass http://nextcloud-enterprise-collabora:9980;
        proxy_set_header Host \$host;
    }
    # Capabilities
    location ^~ /hosting/capabilities {
        proxy_pass http://nextcloud-enterprise-collabora:9980;
        proxy_set_header Host \$host;
    }
    # main websocket
    location ~ ^/cool/(.*)/ws$ {
        proxy_pass http://nextcloud-enterprise-collabora:9980;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 36000s;
    }
    # download, presentation and image upload
    location ~ ^/(c|l)ool {
        proxy_pass http://nextcloud-enterprise-collabora:9980;
        proxy_set_header Host \$host;
    }
    # Admin Console websocket
    location ^~ /cool/adminws {
        proxy_pass http://nextcloud-enterprise-collabora:9980;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 36000s;
    }
    {{- end }}

    {{- if and (eq .Values.TALK_HOST "nextcloud-enterprise-talk") (eq .Values.TALK_ENABLED "yes") }}
    # Config for Talk
    location /standalone-signaling/ {
        proxy_pass http://nextcloud-enterprise-talk:8081/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
    {{- end }}

    {{- if eq .Values.WHITEBOARD_ENABLED "yes" }}
    # Config for Whiteboard
    location /whiteboard/ {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        
        proxy_pass http://nextcloud-enterprise-whiteboard:3002/;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
    {{- end }}

    {{- if and (eq (.Values.ONLYOFFICE_HOST | default "nextcloud-enterprise-onlyoffice") "nextcloud-enterprise-onlyoffice") (eq .Values.ONLYOFFICE_ENABLED "yes") }}
    # Config for OnlyOffice
    location /onlyoffice/ {
        proxy_pass http://nextcloud-enterprise-onlyoffice:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header X-Forwarded-Host \$host/onlyoffice;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    {{- end }}

    {{- if (eq .Values.EUROOFFICE_ENABLED "yes") }}
    # Config for EuroOffice
    location /eurooffice/ {
        proxy_pass http://nextcloud-enterprise-eurooffice:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Prefix /eurooffice;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    {{- end }}

EOL
sed -i "/^.*index index.php index.html \/index.php.*/r /tmp/nginx.config" /tmp/nginx.conf

sed -i '/#add_header Strict-Transport-Security.*/d' /tmp/nginx.conf
sed -i '/fastcgi_param HTTPS/d' /tmp/nginx.conf

sed -i 's|^|    |' /tmp/nginx.conf
cat /tmp/nginx.conf >> ./templates/nextcloud-enterprise-nginx-configmap.yaml
echo '{{- end }}' >> ./templates/nextcloud-enterprise-nginx-configmap.yaml

chmod 777 -R ./
