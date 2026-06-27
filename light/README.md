# n8n-ollama-wiki-agent — Light

A self-hosted, RAG-style internal knowledge assistant. **n8n** orchestrates a
chat agent that answers from a corporate wiki, **Ollama** runs the LLM locally,
**Wiki.js** is the knowledge base, and **PostgreSQL** is the shared datastore
and the agent's memory.

This is the **light** version: each service runs in its own VirtualBox VM,
provisioned with **Vagrant + shell scripts**. No clustering, no HA — the
simplest thing that boots the whole stack end to end. (Heavier versions add
Ansible/Molecule, then Helm/Terraform on Kubernetes.)

## Architecture

```
                 host-only network 192.168.56.0/24
   ┌───────────────┬───────────────┬───────────────┬───────────────┐
   │  postgresql   │    ollama     │     n8n       │    wikijs     │
   │ .13           │ .12           │ .11           │ .14           │
   │ PostgreSQL    │ Ollama LLM    │ n8n (Docker)  │ Wiki.js(Docker)│
   │ shared DB     │ :11434        │ :5678         │ :3000         │
   └───────┬───────┴───────┬───────┴───────┬───────┴───────┬───────┘
           │               │               │               │
           └─ agent_memory ┘               └─ n8n / wikijs DBs ┘
```

| VM | Hostname | IP | Host port | RAM / vCPU |
|----|----------|-----|-----------|------------|
| PostgreSQL | `postgresql` | `192.168.56.13` | — | 2048 MB / 2 |
| Ollama | `ollama` | `192.168.56.12` | — | 4096 MB / 4 |
| n8n | `n8n` | `192.168.56.11` | `5678` | 2048 MB / 2 |
| Wiki.js | `wikijs` | `192.168.56.14` | `3000` | 2048 MB / 2 |

All VMs run `bento/ubuntu-24.04` and resolve each other by hostname (the
`Vagrantfile` seeds `/etc/hosts` on every box).

## Prerequisites

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)
- ~10 GB free RAM for all four VMs running at once

## Quick start

```bash
cd light
cp .env.example .env          # then edit the secrets
vagrant up                    # brings up all four VMs
```

Once provisioning finishes:

- **n8n** — http://localhost:5678 (owner login from `N8N_OWNER_*`)
- **Wiki.js** — http://localhost:3000 (admin login from `WIKIJS_ADMIN_*`)

Bring a single VM up or re-run its provisioner:

```bash
vagrant up postgresql         # start one VM
vagrant provision n8n         # re-run provisioning (idempotent)
vagrant halt                  # stop all
vagrant destroy -f n8n        # tear one down
```

## Configuration

All configuration lives in `light/.env` (copied from `.env.example`). The
`Vagrantfile` loads it and passes every key into the provisioning scripts as
environment variables.

| Key | Purpose |
|-----|---------|
| `N8N_DB_*`, `WIKIJS_DB_*`, `AGENT_DB_*` | Per-service Postgres user / password / database |
| `N8N_ENCRYPTION_KEY` | n8n credential encryption (keep stable across rebuilds) |
| `N8N_VERSION`, `N8N_TZ` | n8n image tag and timezone |
| `N8N_OWNER_*` | Env-managed n8n owner account (no setup screen) |
| `N8N_WORKFLOW_ID` | ID of the demo workflow to import/activate |
| `WIKIJS_ADMIN_*`, `WIKIJS_SITE_URL` | Wiki.js admin account and site URL |
| `OLLAMA_MODELS`, `OLLAMA_VERSION` | Models to pull (space/comma separated) and image tag |

> **Secrets:** `.env` is git-ignored. `.env.example` holds throwaway defaults —
> replace them before any real use.

## How provisioning works

Each VM has a shell provisioner under `provisioning/`. Docker VMs run
`install-docker.sh` first.

- **`provisioning/postgresql.sh`** — installs PostgreSQL, opens it to the
  private subnet, and creates a database + role per service (`n8n`, `wikijs`,
  and `agent` → `agent_memory`). Passwords are re-synced every run.
- **`provisioning/ollama.sh`** — runs the Ollama container and pulls the models
  in `OLLAMA_MODELS`. API on `:11434`.
- **`provisioning/n8n.sh`** + **`provisioning/n8n/`** — Docker Compose against
  the shared Postgres. Seeds an env-managed owner, imports the postgres/ollama
  credentials the demo workflow needs, then imports and activates the workflow
  (**Chat → AI Agent → Ollama + Postgres memory**).
- **`provisioning/wikijs.sh`** + **`provisioning/wikijs/`** — Docker Compose
  against the shared Postgres. Auto-creates the admin via the setup wizard's
  `/finalize` endpoint and seeds content pages (`home.md`, `vagrant-setup.md`)
  over the GraphQL API.

All provisioners are idempotent — re-running `vagrant provision <vm>` is safe.

## Layout

```
light/
├── Vagrantfile                 # VM definitions, .env loading, /etc/hosts
├── .env.example                # configuration template
└── provisioning/
    ├── install-docker.sh       # Docker install (Docker VMs)
    ├── postgresql.sh           # shared database + per-service roles
    ├── ollama.sh               # Ollama container + model pull
    ├── n8n.sh                  # n8n: owner, credentials, demo workflow
    ├── n8n/                    # compose files + workflow.json
    ├── wikijs.sh               # Wiki.js: admin + seeded pages
    └── wikijs/                 # compose file + page markdown
```

## Troubleshooting

- **n8n loses the DB after you restart/reprovision Postgres** — n8n doesn't
  recover a dropped connection on its own; restart it:
  `vagrant ssh n8n -c 'cd /opt/n8n && docker compose restart'`.
- **Re-test Wiki.js first-run setup without rebuilding the VM** — drop its
  database on the Postgres VM, then re-provision:
  `vagrant ssh postgresql -c "sudo -u postgres psql -c 'DROP DATABASE wikijs WITH (FORCE);' -c 'CREATE DATABASE wikijs OWNER wikijs;'"`
- **`vagrant destroy` doesn't reset app state** — app state lives in the
  Postgres VM, not the app VMs. Reset the relevant database to start fresh.
