# n8n-ollama-wiki-agent

A self-hosted, RAG-style **internal knowledge assistant** for infrastructure
and operations. Instead of tribal knowledge living in a few people's heads — the
classic *"only Max knows that, and he just quit"* problem — this is an
agent-assistant that doesn't hallucinate: it answers from a corporate wiki and
cites its sources.

A new hire (or anyone on call) asks *"how is our infrastructure set up?"* and
gets a clear, referenced answer.

## The stack

| Component | Role |
|-----------|------|
| **n8n** | Orchestrator — hosts the chat agent and its workflow |
| **Ollama** | Local LLM (no data leaves the network) |
| **Wiki.js** | Corporate knowledge base the agent answers from |
| **PostgreSQL** | Shared datastore and the agent's conversational memory |

The agent runs in n8n, talks to the LLM via Ollama, draws knowledge from
Wiki.js, and keeps per-conversation memory in PostgreSQL.

## Versions

The same system is built three times, each raising the infrastructure bar. Pick
the directory that matches how much you want to take on:

| Version | Tooling | Status |
|---------|---------|--------|
| **[Light](./light/README.md)** | Vagrant + shell provisioning | ✅ Available |
| **Normal** | Ansible roles + Molecule, versioned | 🚧 Planned |
| **Hard / Expert** | Helm + Terraform on Kubernetes | 🚧 Planned |

Later stages also layer on the "grown-up" pieces: Redis, a reverse proxy,
monitoring and centralized logging, and everything-as-code.

## Getting started

Start with the light version — it brings the whole stack up locally with a
single `vagrant up`:

➡️ **[light/README.md](./light/README.md)**

## What you'll learn

- Building a local chat-bot agent in n8n that calls an LLM through Ollama and
  keeps conversational state.
- Automating deployment progressively: **Vagrant + shell** (Light), then
  **Ansible + Molecule** (Normal), then **Helm / Terraform** (Hard).
- Running the classic operational concerns — networking, persistence,
  monitoring — across a multi-node system.
