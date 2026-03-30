#!/bin/bash
# =============================================================================
# deploy/init-letsencrypt.sh
#
# Egyszeri futtatandó script az első SSL tanúsítvány beszerzéséhez.
# A probléma: az Nginx-nek kell a cert hogy elinduljon, de a Certbot-nak
# kell a futó Nginx a domain hitelesítéshez. Megoldás: ideiglenes dummy cert.
#
# Futtatás a REPO GYÖKÉRBŐL:
#   chmod +x deploy/init-letsencrypt.sh
#   ./deploy/init-letsencrypt.sh
# =============================================================================

set -e

DOMAIN="api.holadohi.hu"
EMAIL="akos@csaba.vip"
COMPOSE="docker compose"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

echo "=== 1/5 — Ideiglenes self-signed tanúsítvány létrehozása ==="

$COMPOSE run --rm --entrypoint "\
  mkdir -p $CERT_PATH" certbot

$COMPOSE run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout $CERT_PATH/privkey.pem \
    -out $CERT_PATH/fullchain.pem \
    -subj '/CN=$DOMAIN'" certbot

echo "=== 2/5 — Nginx indítása az ideiglenes tanúsítvánnyal ==="
$COMPOSE up -d nginx

echo "=== 3/5 — Ideiglenes tanúsítvány törlése ==="
$COMPOSE run --rm --entrypoint "\
  rm -rf /etc/letsencrypt/live/$DOMAIN && \
  rm -rf /etc/letsencrypt/archive/$DOMAIN && \
  rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf" certbot

echo "=== 4/5 — Valódi Let's Encrypt tanúsítvány igénylése ==="
$COMPOSE run --rm --entrypoint "certbot" certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN"

echo "=== 5/5 — Nginx újraindítása a valódi tanúsítvánnyal ==="
$COMPOSE exec nginx nginx -s reload

echo ""
echo "✅ HTTPS sikeresen beállítva: https://$DOMAIN"
echo ""
echo "A tanúsítvány 90 napig érvényes. A certbot container"
echo "automatikusan megújítja 12 óránként (ha szükséges)."