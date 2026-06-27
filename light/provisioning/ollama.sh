#!/bin/bash

set -euo pipefail

OLLAMA_VERSION="${OLLAMA_VERSION:-0.30.11}"
# space or comma-separated list of models to pull, e.g. "lamma3.2 nomic-embed-text"
OLLAMA_MODELS="${OLLAMA_MODELS:-gemma2:2b}"

# Start container if not already
if [ -z "$(docker ps -aq -f name='^ollama$')" ]; then
  docker run -d --restart unless-stopped \
   -v ollama:/root/.ollama -p 11434:11434 \
  --name ollama "ollama/ollama:${OLLAMA_VERSION}"
else
  docker start ollama
fi

echo "waiting for ollama API on :11434..."
for _ in $(seq 1 30); do
  docker exec ollama ollama list >/dev/null 2>&1 && break
  sleep 2
done

# pull each requested model, fail if any is missing
failed=()
for model in ${OLLAMA_MODELS//,/ }; do
  echo "pulling ${model}..."
  docker exec ollama ollama pull "${model}" || failed+=("${model}")
done

if [ "${#failed[@]}" -gt 0 ]; then 
  echo "ERROR: could not pull: ${failed[*]}" >&2
  exit 1
fi
