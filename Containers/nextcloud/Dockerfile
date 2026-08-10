# syntax=docker/dockerfile:latest
FROM php:8.3.31-fpm-alpine3.24

ENV PHP_MEMORY_LIMIT=512M
ENV PHP_UPLOAD_LIMIT=16G
ENV PHP_MAX_TIME=3600
COPY --chmod=775 healthcheck.sh /healthcheck.sh
ENV REDIS_DB_INDEX=0




VOLUME /mnt/ncdata
VOLUME /var/www/html

# Custom: change id of www-data user as it needs to be the same like on old installations
# hadolint ignore=SC2086,DL3003
RUN set -ex; \
    apk upgrade --no-cache -a; \
    apk add --no-cache shadow; \
    deluser www-data; \
    addgroup -g 33 -S www-data; \
    adduser -u 33 -D -S -G www-data www-data; \
    \
# entrypoint.sh and cron.sh dependencies
    apk add --no-cache \
        rsync \
    ; \
# install the PHP extensions we need
# see https://docs.nextcloud.com/server/stable/admin_manual/installation/source_installation.html
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        autoconf \
        freetype-dev \
        gmp-dev \
        icu-dev \
        imagemagick-dev \
        imagemagick-svg \
        imagemagick-heic \
        imagemagick-tiff \
        libevent-dev \
        libjpeg-turbo-dev \
        libmcrypt-dev \
        libmemcached-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libzip-dev \
        openldap-dev \
        pcre-dev \
        postgresql-dev \
    ; \
    \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-configure ftp --with-openssl-dir=/usr; \
    docker-php-ext-configure ldap; \
    docker-php-ext-install -j "$(nproc)" \
        bcmath \
        exif \
        gd \
        gmp \
        intl \
        ldap \
        opcache \
        pcntl \
        pdo_pgsql \
        pdo_mysql \
        sysvsem \
        zip \
    ; \
    \
# pecl will claim success even if one install fails, so we need to perform each install separately
    pecl install -o igbinary-3.2.16; \
    pecl install APCu-5.1.28; \
    pecl install -D 'enable-memcached-igbinary="yes"' memcached-3.4.0; \
    pecl install -oD 'enable-redis-igbinary="yes" enable-redis-zstd="yes" enable-redis-lz4="yes"' redis-6.3.0; \
   pecl install -o imagick-3.8.1; \
    \
    docker-php-ext-enable \
        igbinary \
        apcu \
        memcached \
        redis \
        imagick \
    ; \
    rm -r /tmp/pear; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .nextcloud-phpext-rundeps $runDeps; \
    apk del .build-deps; \
    \
    { \
        echo 'apc.serializer=igbinary'; \
        echo 'session.serialize_handler=igbinary'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-igbinary.ini; \
    \
# set recommended PHP.ini settings
# see https://docs.nextcloud.com/server/stable/admin_manual/installation/server_tuning.html#enable-php-opcache and below
    { \
        echo 'opcache.max_accelerated_files=20000'; \
        echo 'opcache.memory_consumption=256'; \
        echo 'opcache.interned_strings_buffer=64'; \
        echo 'opcache.save_comments=1'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.jit=1255'; \
        echo 'opcache.jit_buffer_size=128M'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
    \
    { \
        echo 'apc.enable_cli=1'; \
        echo 'apc.shm_size=128M'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini; \
    \
    { \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_TIME}'; \
        echo 'max_input_time=-1'; \
        echo 'default_socket_timeout=${PHP_MAX_TIME}'; \
        echo 'output_buffering=0'; \
        echo 'realpath_cache_size=8M'; \
        echo 'realpath_cache_ttl=600'; \
    } > /usr/local/etc/php/conf.d/nextcloud.ini; \
    \
    { \
        echo 'session.save_handler = ${REDIS_MODE}'; \
        echo 'session.save_path = "${REDIS_CONNECT_STRING}"'; \
        echo 'redis.session.locking_enabled = 1'; \
        echo 'redis.session.lock_retries = -1'; \
        echo '; 100ms in microseconds - prevents timeout on long requests such as large file uploads'; \
        echo 'redis.session.lock_wait_time = 100000'; \
        echo '; prevents stale locks from crashed workers (seconds)'; \
        echo 'redis.session.lock_expire = 60'; \
        echo 'session.gc_maxlifetime = 86400'; \
    } > /usr/local/etc/php/conf.d/redis-session.ini; \
    \
    mkdir -p /var/www/data; \
    chown -R www-data:root /var/www; \
    chmod -R g=u /var/www; \
    \
    \
# Template from https://github.com/nextcloud/docker/blob/master/.examples/dockerfiles/full/fpm-alpine/Dockerfile
    apk add --no-cache \
        ffmpeg \
        procps \
        samba-client \
        supervisor \
#       libreoffice \
    ; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        imap-dev \
        krb5-dev \
        openssl-dev \
        samba-dev \
        bzip2-dev \
        libpq-dev \
    ; \
    \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install \
        bz2 \
        imap \
        pgsql \
        ftp \
    ; \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .nextcloud-phpext-rundeps $runDeps; \
    apk del .build-deps; \
    \
    mkdir -p \
    /var/log/supervisord \
    /var/run/supervisord \
    ; \
    chmod 777 -R /var/log/supervisord; \
    chmod 777 -R /var/run/supervisord; \
    \
    apk add --no-cache \
        bash \
        netcat-openbsd \
        openssl \
        gnupg \
        git \
        postgresql-client \
        tzdata \
        sudo \
        grep \
        nodejs \
        bind-tools \
        imagemagick \
        imagemagick-svg \
        imagemagick-heic \
        imagemagick-tiff \
        coreutils unzip openldap-clients; \
    \
    grep -q '^pm = dynamic' /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's/^pm = dynamic/pm = ondemand/' /usr/local/etc/php-fpm.d/www.conf; \
# Sync this with max db connections and MaxRequestWorkers
# We don't actually expect so many children but don't want to limit it artificially because people will report issues otherwise.
# Also children will usually be terminated again after the process is done due to the ondemand setting
    sed -i 's/^pm.max_children =.*/pm.max_children = 5000/' /usr/local/etc/php-fpm.d/www.conf; \
# With pm = ondemand, workers are killed after pm.process_idle_timeout seconds
# of inactivity.  The upstream default is 10 s, which is aggressive: after a
# brief quiet period (e.g. desktop-sync clients polling every few seconds), all
# workers are reaped and the next request burst must wait for fresh forks.  On
# a loaded host that spawn latency can push Apache past its FastCGI timeout and
# produce a 502.  300 s (5 min) keeps a warm pool through normal sync-client
# polling cycles while still reclaiming memory during genuinely idle periods.
    sed -i 's/^;*pm.process_idle_timeout\s*=.*/pm.process_idle_timeout = 300s/' /usr/local/etc/php-fpm.d/www.conf; \
# Set request_terminate_timeout so that PHP-FPM forcibly kills workers that
# exceed the wall-clock limit.  Without this (default = 0 = disabled) a worker
# stuck on a slow DB query, a stalled Redis connection, or a hung syscall is
# never reaped.  Over time these zombies fill up pm.max_children, leaving no
# free slots for legitimate requests and causing Apache to return 502 Bad
# Gateway upstream.
    sed -i "s|^;*request_terminate_timeout = .*|request_terminate_timeout = \${PHP_MAX_TIME}|" /usr/local/etc/php-fpm.d/www.conf; \
    sed -i 's|access.log = /proc/self/fd/2|access.log = /proc/self/fd/1|' /usr/local/etc/php-fpm.d/docker.conf; \
    \
    echo "[ -n \"\$TERM\" ] && [ -f /root.motd ] && cat /root.motd" >> /root/.bashrc; \
    \
    chmod 777 -R /usr/src && \
    chmod 777 -R /usr/local/etc/php/conf.d && \
    chmod 777 -R /usr/local/etc/php-fpm.d && \
    chmod -R 777 /tmp; \
    chmod -R 777 /etc/openldap; \
    \
    mkdir -p /nc-updater; \
    chmod -R 777 /nc-updater

# hadolint ignore=DL3002
USER 33
ENTRYPOINT ["php-fpm"]

HEALTHCHECK CMD /healthcheck.sh
