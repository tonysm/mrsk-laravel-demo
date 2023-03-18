#!/usr/bin/env bash

set -e

php artisan optimize
php artisan view:cache

# Run a command or supervisord
if [ $# -gt 0 ];then
    # If we passed a command, run it
    exec "$@"
else
    # Otherwise, attempt to migrate and then start supervisord...
    php artisan migrate --force

    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
