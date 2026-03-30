#!/bin/bash
# =============================================================================
# deploy/renew-certs.sh
#
# Cron job: hetente lefuttatja a certbot renew-t és újratölti az Nginx-et.
# A certbot csak akkor újít, ha a cert 30 napon belül lejár.
#
# Crontab bejegyzés (root user):
#   0 3 * * 1 /var/www/deploy/renew-certs.sh >> /var/log/certbot-renew.log 2>&1
# =============================================================================

set -e

cd /var/www

docker compose run --rm certbot renew
docker compose exec nginx nginx -s reload