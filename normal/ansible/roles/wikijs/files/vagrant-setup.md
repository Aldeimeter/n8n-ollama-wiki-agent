# Vagrant Configuration — Light Version

> **This is the _light_ version of the stack.** Every service runs in its own
> VirtualBox VM provisioned by Vagrant, with all application services kept as
> simple as possible (single containers, one shared PostgreSQL, no clustering
> or HA). All paths below are relative to the **git project root**.

## Overview

Four Linux VMs (`bento/ubuntu-24.04`) on a shared host-only network. One VM
hosts PostgreSQL; the other three run their app in Docker and talk to that
shared database by hostname.

| VM | Hostname | IP | Host port | RAM / vCPU | Provisioner |
|----|----------|-----|-----------|------------|-------------|
| PostgreSQL | `postgresql` | `192.168.56.13` | — | 2048 MB / 2 | `light/provisioning/postgresql.sh` |
| Ollama | `ollama` | `192.168.56.12` | — | 4096 MB / 4 | `light/provisioning/ollama.sh` |
| n8n | `n8n` | `192.168.56.11` | `5678` | 2048 MB / 2 | `light/provisioning/n8n.sh` |
| Wiki.js | `wikijs` | `192.168.56.14` | `3000` | 2048 MB / 2 | `light/provisioning/wikijs.sh` |

## Topology & networking

- Defined in **`light/Vagrantfile`** from a single `VMS` hash — one entry per VM.
- Every VM joins the private network `192.168.56.0/24`, so they reach each
  other by IP and by name.
- The `Vagrantfile` seeds `/etc/hosts` on each VM with the whole stack, so
  services connect via hostnames like `postgresql:5432` and `ollama:11434`.
- Configuration values (DB users/passwords, models, owner credentials) are
  loaded from **`light/.env`** (see **`light/.env.example`**) and passed into
  each provisioning script as environment variables.
- VMs that run Docker get **`light/provisioning/install-docker.sh`** first.

## Services

### PostgreSQL — shared database
`light/provisioning/postgresql.sh`

Installs PostgreSQL, opens it to the private subnet
(`host all all 192.168.56.0/24 scram-sha-256`), and creates a separate
database + role per service: **n8n**, **wikijs**, and **agent** (the
`agent_memory` DB used by the AI agent). Role passwords are re-synced on every
run so they always match `.env`.

### Ollama — local LLM
`light/provisioning/ollama.sh`

Runs the Ollama container and pulls the models listed in `OLLAMA_MODELS`
(space/comma separated). The API is served on `:11434` and reached by other
VMs as `http://ollama:11434`.

### n8n — workflow automation
`light/provisioning/n8n.sh` · `light/provisioning/n8n/`

- Runs via Docker Compose (`docker-compose.yml`) against the shared PostgreSQL.
- Owner account is **managed by environment** (no manual setup screen): the
  password is bcrypt-hashed at provision time and injected via `owner.env`.
- Seeds the credentials the demo workflow needs (`credentials.json`, generated
  from `.env`) with IDs matching `workflow.json`, then imports and publishes
  the workflow.
- Demo workflow: **Chat Message → AI Agent → Ollama Chat Model + Postgres Chat
  Memory**, so the agent answers via Ollama and remembers context across
  messages using PostgreSQL.

### Wiki.js — this wiki
`light/provisioning/wikijs.sh` · `light/provisioning/wikijs/`

- Runs via Docker Compose (`docker-compose.yml`) against the shared PostgreSQL.
- The root admin is created automatically through the setup wizard's
  `/finalize` endpoint — no manual registration.
- Seeds content pages (including this one) from markdown files such as
  `light/provisioning/wikijs/home.md` and
  `light/provisioning/wikijs/vagrant-setup.md` via the GraphQL API.

## Running it

```bash
cd light
cp .env.example .env   # then edit secrets
vagrant up             # brings up all four VMs in order
```

- n8n UI: `http://localhost:5678`
- Wiki.js: `http://localhost:3000`

Re-running `vagrant provision <vm>` is safe — every provisioner is idempotent.
