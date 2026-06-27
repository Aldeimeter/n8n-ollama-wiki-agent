#!/bin/bash

set -euo pipefail

# Install postgresql
export DEBIAN_FRONTEND=noninteractive
if ! dpkg -s postgresql > /dev/null 2>&1; then
  apt-get update
  apt-get install -y postgresql
fi

# detect installed major version
PG_VER="$(pg_lsclusters -h | awk 'NR==1 { print $1 }')"
PG_CONF_DIR="/etc/postgresql/$PG_VER/main"

# Networking
install -d "$PG_CONF_DIR/conf.d"
cat > "$PG_CONF_DIR/conf.d/99-vagrant.conf" << 'EOF'
listen_addresses = '*'
EOF

# Allow password auth from private subnet
HBA="${PG_CONF_DIR}/pg_hba.conf"
LINE="host    all    all   192.168.56.0/24 scram-sha-256"
grep -qF "$LINE" "$HBA" || echo "${LINE}" >> "$HBA"

# users and databases
create_db() {
  local user="$1" pass="$2" db="$3"
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${user}'" | grep -q 1 \
    || sudo -u postgres psql -c "CREATE ROLE ${user} LOGIN PASSWORD '${pass}';"
  # Re-sync password every run so it always matches .env (idempotent).
  sudo -u postgres psql -c "ALTER ROLE ${user} WITH LOGIN PASSWORD '${pass}';"
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1 \
    || sudo -u postgres createdb -O "${user}" "${db}"
}

create_db "${N8N_DB_USER:-n8n}" "${N8N_DB_PASS:-changeme}" "${N8N_DB_NAME:-n8n}"
create_db "${WIKIJS_DB_USER:-wikijs}" "${WIKIJS_DB_PASS:-changeme}" "${WIKIJS_DB_NAME:-wikijs}"
create_db "${AGENT_DB_USER:-agent}" "${AGENT_DB_PASS:-changeme}" "${AGENT_DB_NAME:-agent_memory}"

# Apply networking changes 
systemctl enable postgresql
systemctl restart postgresql

