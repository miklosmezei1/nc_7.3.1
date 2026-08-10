
if [ "$AIRGAPPED" = yes ]; then
    php /var/www/html/occ config:system:set has_internet_connection --type bool --value false
    php /var/www/html/occ config:system:set updatechecker --type bool --value false
    php /var/www/html/occ config:system:set has_valid_subscription --type bool --value true
fi

# Change some value to a random one inside the config and delete it afterwards in order to write out the config.php file
# This is a hack but no better solution was found for the meantime in order to apply all values always during a restart of the container
php /var/www/html/occ config:system:set aio_updated_config_hash --type bool --value true
php /var/www/html/occ config:system:delete aio_updated_config_hash

# Run CMD
echo "Container is finished and cronjob just started"
exec "$@"