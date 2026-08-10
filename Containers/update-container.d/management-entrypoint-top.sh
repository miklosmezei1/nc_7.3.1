
# Check that db type is not empty
if [ -z "$DATABASE_TYPE" ]; then
    export DATABASE_TYPE=postgres
fi
# Check supported db types
if [ "$DATABASE_TYPE" != postgres ] && [ "$DATABASE_TYPE" != mysql ]; then
    echo "DB type must be either postgres or mysql"
    exit 1
fi

# Set a default value for POSTGRES_PORT
if [ -z "$POSTGRES_PORT" ]; then
    export POSTGRES_PORT=5432
fi

# Only start container if database is accessible
# shellcheck disable=SC2153
while ! nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"; do
    echo "Waiting for database to start..."
    sleep 5
done

# Use the correct Postgres username
if [ "$POSTGRES_USER" = nextcloud ]; then
    POSTGRES_USER="oc_$POSTGRES_USER"
    export POSTGRES_USER
fi

# Wait for database
# Pass the connection details via libpq environment variables instead of a
# postgresql:// URI. The password is taken verbatim from PGPASSWORD, so special
# characters (% & @ : # ...) work without URI percent-encoding.
if [ "$DATABASE_TYPE" = postgres ] && [ -z "$NEXTCLOUD_TRUSTED_CERTIFICATES_POSTGRES" ]; then
    while ! PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "select now()"; do
        echo "Waiting for the database to start..."
        sleep 5
    done
fi

# Make config writeable again
if [ -f /var/www/html/config/config.php ]; then
    sed -i "/config_is_read_only/s/true/false/" /var/www/html/config/config.php
fi

# Download enterprise archive and unpack it
if [ -z "$ENTERPRISE_ARCHIVE_URL" ]; then
    echo "ENTERPRISE_ARCHIVE_URL needs to be set"
    exit 1
fi
set -ex
# shellcheck disable=SC2001
ENTERPRISE_ARCHIVE_VERSION="$(echo "$ENTERPRISE_ARCHIVE_URL" | sed 's|.*/||g')"
if ! [ -f "/mnt/ncdata/$ENTERPRISE_ARCHIVE_VERSION" ]; then
    touch "$NEXTCLOUD_DATA_DIR/install.failed"
    if ! [ -f "/mnt/archive/$ENTERPRISE_ARCHIVE_VERSION" ]; then
        if env | grep -q NEXTCLOUD_TRUSTED_CERTIFICATES_; then
            export CURL_CA_BUNDLE="/var/www/html/data/certificates/ca-bundle.crt"
        fi
        echo "Downloading enterprise archive..."
        curl -fSL -o "/mnt/ncdata/$ENTERPRISE_ARCHIVE_VERSION" "$ENTERPRISE_ARCHIVE_URL"
    else
        cp "/mnt/archive/$ENTERPRISE_ARCHIVE_VERSION" "/mnt/ncdata/"
    fi
    rm -rf "$SOURCE_LOCATION"
    mkdir -p "$SOURCE_LOCATION"
    echo "Extracting zip file..."
    unzip "/mnt/ncdata/$ENTERPRISE_ARCHIVE_VERSION" -d "/mnt/ncdata/nextcloud-enterprise-source/" | awk 'BEGIN {ORS=" "} {count++} {if(NR%500==0)print "Extracted " count " files\n"} END {print "Extracted " count " files in total\n"}'
    mkdir -p "$SOURCE_LOCATION"/data
    mkdir -p "$SOURCE_LOCATION"/custom_apps
    mkdir -p "$SOURCE_LOCATION"/config
    cp /usr/src/config/* "$SOURCE_LOCATION"/config
    # shellcheck disable=SC2001
    ENTERPRISE_ARCHIVE_VERSION=$(echo "$ENTERPRISE_ARCHIVE_VERSION" | sed 's|\.zip$||')
    if [ -d "/mnt/archive/$ENTERPRISE_ARCHIVE_VERSION/custom_apps/" ]; then
        APP_ARCHIVES="$(find "/mnt/archive/$ENTERPRISE_ARCHIVE_VERSION/custom_apps/" -name '*.tar.gz')"
        mapfile -t APP_ARCHIVES <<< "$APP_ARCHIVES"
        for archive in "${APP_ARCHIVES[@]}"; do
            tar -zxvf "$archive" -C "$SOURCE_LOCATION/custom_apps/"
        done
    fi
    set +ex
    chown "$(id -u):$(id -g)" -R "$SOURCE_LOCATION"
    chmod 770 -R "$SOURCE_LOCATION"
    rm "$NEXTCLOUD_DATA_DIR/install.failed"
fi
set +ex

