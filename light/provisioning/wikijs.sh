#!/bin/bash

set -euo pipefail

# jq is used to safely build the GraphQL payloads below.
command -v jq >/dev/null || { apt-get update -qq && apt-get install -y jq; }

install -d /opt/wikijs
cp /vagrant/provisioning/wikijs/docker-compose.yml /opt/wikijs/

umask 077
cat > /opt/wikijs/.env << EOF
WIKIJS_DB_NAME=${WIKIJS_DB_NAME:-wikijs}
WIKIJS_DB_USER=${WIKIJS_DB_USER:-wikijs}
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

# /finalize destroys the setup HTTP server and reboots into normal mode, so
# wait for the API to come back before using GraphQL.
echo "waiting for wiki.js to come back up..."
for _ in $(seq 1 30); do
  curl -fsS -o /dev/null http://localhost:3000 2>/dev/null && break
  sleep 2
done

# Seed the home page. Runs every provision and never aborts the run: re-runs
# hit the unique-path constraint and just report "already exists".
login=$(jq -n --arg u "$ADMIN_EMAIL" --arg p "$ADMIN_PASS" \
  '{query:"mutation($u:String!,$p:String!){authentication{login(username:$u,password:$p,strategy:\"local\"){jwt}}}",variables:{u:$u,p:$p}}')
jwt=$(curl -fsS -X POST http://localhost:3000/graphql \
  -H 'Content-Type: application/json' -d "$login" 2>/dev/null \
  | jq -r '.data.authentication.login.jwt // empty')

if [ -z "$jwt" ]; then
  echo "WARN: could not log in to seed home page; skipping" >&2
else
  content=$(cat /vagrant/provisioning/wikijs/home.md)
  page=$(jq -n --arg c "$content" \
    '{query:"mutation($c:String!){pages{create(content:$c,description:\"\",editor:\"markdown\",isPublished:true,isPrivate:false,locale:\"en\",path:\"home\",tags:[],title:\"Home\"){responseResult{succeeded message}}}}",variables:{c:$c}}')
  result=$(curl -fsS -X POST http://localhost:3000/graphql \
    -H "Authorization: Bearer ${jwt}" -H 'Content-Type: application/json' \
    -d "$page" 2>/dev/null || true)
  echo "home page: $(echo "$result" | jq -r '.data.pages.create.responseResult.message // .errors[0].message // "no response"')"
fi
