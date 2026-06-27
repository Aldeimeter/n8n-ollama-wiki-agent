#!/bin/bash

set -euo pipefail

install -d /opt/n8n
cp /vagrant/provisioning/n8n/docker-compose.yml /opt/n8n/

umask 077
cat > /opt/n8n/.env << EOF
N8N_VERSION=${N8N_VERSION:-stable}
N8N_DB_NAME=${N8N_DB_NAME:-n8n}
N8N_DB_USER=${N8N_DB_USER:-n8n}
N8N_DB_PASS=${N8N_DB_PASS:-changeme}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-}
TZ=${N8N_TZ:-UTC}
EOF


cd /opt/n8n 

WF="/vagrant/provisioning/n8n/workflow.json"
WF_ID="${N8N_WORKFLOW_ID:-demo0001}"
files=(-f docker-compose.yml)
[ -f "$WF" ] && files+=(-f /vagrant/provisioning/n8n/docker-compose.workflow.yml)

docker compose "${files[@]}" pull

echo "waiting for postgresql:5432..."
ready=0
for _ in $(seq 1 30); do
  if (echo > /dev/tcp/postgresql/5432) >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done

if [ "$ready" -ne 1 ]; then
  echo "ERROR: postgresql:5432 not reachable after 60s — is the postgresql VM up?" >&2
  exit 1
fi

if [ -f "$WF" ] && \
  ! docker compose "${files[@]}" run --rm n8n export:workflow --id="$WF_ID" --output=/tmp/p.json >/dev/null 2>&1; then
  
  docker compose "${files[@]}" run --rm n8n import:workflow --input=/workflow.json \
    || echo "import returned non-zero (often a non-fatal warning); continuing"

  # n8n 2.0 uses publish:workflow, older 1.x uses update:workflow --active=true
  docker compose "${files[@]}" run --rm n8n publish:workflow --id="$WF_ID" \
  || docker compose "${files[@]}" run --rm n8n update:workflow --id="$WF_ID" --active=true \
  || echo "couldn't auto-publish $WF_ID - activate it once in the UI"
fi

docker compose "${files[@]}" up -d
echo "n8n up on :5678"
