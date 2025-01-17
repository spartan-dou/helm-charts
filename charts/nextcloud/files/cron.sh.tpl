#!/bin/sh

echo "$(date) : Begining of cron..."
php /var/www/html/occ preview:pre-generate
echo "$(date) : End of cron."