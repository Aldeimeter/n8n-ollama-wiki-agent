#!/bin/bash

set -euo pipefail


install -d /opt/wikijs
cp /vagrant/provisioning/wikijs/docker-compose.yml /opt/wikijs/

umask 077
cat > /opt/wikijs/.env << EOF
WIKIJS_DB_NAME=${WIKIJS_DB_NAME:-n8n}
WIKIJS_DB_USER=${WIKIJS_DB_USER:-n8n}
WIKIJS_DB_PASS=${WIKIJS_DB_PASS:-changeme}
EOF


cd /opt/wikijs && docker compose up -d

ADMIN_EMAIL="${WIKIJS_ADMIN_EMAIL:-admin@admin.com}"
ADMIN_PASS="${WIKIJS_ADMIN_PASS:-changeme}"
SITE_URL="${WIKIJS_SITE_URL:-http://localhost:3000}"

echo "waiting for wiki.js on :3000"

for _ in $(seq 1 30); do
  curl -fsS -o /dev/null http://localhost:3000 && break;
  sleep 2
done

code=$(curl -fsS -o /dev/null -w '%{http_code}' \
      -X POST http://localhost:3000/finalize \
      -H 'Content-Type: application/json' \
      -d "{\"adminEmail\":\"${ADMIN_EMAIL}\",\"adminPassword\":\"${ADMIN_PASS}\",\"adminPasswordConfirm\":\"${ADMIN_PASS}\",\"siteUrl\":\"${SITE_URL}\",\"telemetry\":false}" \
) 2>/dev/null || true

case "$code" in 
  200) echo "wiki.js admin created: ${ADMIN_EMAIL}" ;;
  404) echo "wiki.js already configured; skipping admin setup" ;;
  *)   echo "WARN: /finalize returned HTTP ${code:-none}; finish setup in the UI" >&2 ;;
esac
