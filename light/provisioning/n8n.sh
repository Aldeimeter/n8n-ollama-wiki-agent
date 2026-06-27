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

if [ "${N8N_OWNER_MANAGED_BY_ENV:-false}" = "true" ]; then

  # htpasswd (apache2-utils) is used to bcrypt-hash the owner password below.
  command -v htpasswd >/dev/null || { apt-get update -qq && apt-get install -y apache2-utils; }
  OWNER_PASS_HASH="$(htpasswd -bnBC 10 "" "${N8N_OWNER_PASSWORD:-changeme}" \
   | tr -d '\n' | cut -d: -f2- | sed 's/^\$2y\$/$2a$/')"

  cat > /opt/n8n/owner.env << EOF
N8N_INSTANCE_OWNER_MANAGED_BY_ENV=true
N8N_INSTANCE_OWNER_EMAIL=${N8N_OWNER_EMAIL:-admin@admin.com}
N8N_INSTANCE_OWNER_FIRST_NAME=${N8N_OWNER_FIRST_NAME:-Admin}
N8N_INSTANCE_OWNER_LAST_NAME=${N8N_OWNER_LAST_NAME:-User}
# Single-quoted so Compose treats the hash literally; without this it
# interpolates the '$' segments of the bcrypt hash into blank strings.
N8N_INSTANCE_OWNER_PASSWORD_HASH='${OWNER_PASS_HASH}'
EOF
else
  : > /opt/n8n/owner.env # empty file -> env_file loads nothing, feature stays off
fi

# Credentials the demo workflow references. Workflows don't carry their
# credentials, so we seed them here with the exact IDs baked into
# workflow.json (so the node references resolve). Rendered from env with jq
# for safe escaping; n8n encrypts the plaintext data on import.
command -v jq >/dev/null || { apt-get update -qq && apt-get install -y jq; }
jq -n \
  --arg pgdb "${AGENT_DB_NAME:-agent_memory}" \
  --arg pguser "${AGENT_DB_USER:-agent}" \
  --arg pgpass "${AGENT_DB_PASS:-changeme}" \
  '[
    {id:"kF643xZ6lToMuekg", name:"Postgres account", type:"postgres",
     data:{host:"postgresql", database:$pgdb, user:$pguser, password:$pgpass, port:5432, ssl:"disable"}},
    {id:"tSXCUNSIyymDwWym", name:"Ollama account", type:"ollamaApi",
     data:{baseUrl:"http://ollama:11434"}}
  ]' > /opt/n8n/credentials.json
# n8n runs as UID 1000 (node) inside the container; umask 077 made this file
# root-only, so hand ownership to 1000 so the container can read it while it
# stays non-world-readable (it holds the DB password).
chown 1000:1000 /opt/n8n/credentials.json

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

if [ -f "$WF" ]; then
  # Seed credentials first (idempotent) so the workflow's references resolve.
  # Runs every provision, independent of whether the workflow already exists —
  # the broken state is a re-provision where the workflow is present but its
  # credentials are not.
  docker compose "${files[@]}" run --rm n8n import:credentials --input=/credentials.json \
    || echo "credential import returned non-zero; continuing"

  # Import + publish the workflow only if it isn't already present.
  if ! docker compose "${files[@]}" run --rm n8n export:workflow --id="$WF_ID" --output=/tmp/p.json >/dev/null 2>&1; then

    docker compose "${files[@]}" run --rm n8n import:workflow --input=/workflow.json \
      || echo "import returned non-zero (often a non-fatal warning); continuing"

    # n8n 2.0 uses publish:workflow, older 1.x uses update:workflow --active=true
    docker compose "${files[@]}" run --rm n8n publish:workflow --id="$WF_ID" \
    || docker compose "${files[@]}" run --rm n8n update:workflow --id="$WF_ID" --active=true \
    || echo "couldn't auto-publish $WF_ID - activate it once in the UI"
  fi
fi

docker compose "${files[@]}" up -d
echo "n8n up on :5678"
