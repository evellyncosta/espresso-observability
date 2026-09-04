#!/usr/bin/env bash

set -Eeuo pipefail

signoz_dir="${SIGNOZ_DIR:-/data/signoz}"
signoz_ui_port="${SIGNOZ_UI_PORT:-8081}"
foundry_bin="${FOUNDRY_BIN_PATH:-/usr/local/bin/foundryctl}"
collector_dir="${POSTGRES_COLLECTOR_DIR:-/data/signoz-integrations/postgres-collector}"
collector_container="${POSTGRES_COLLECTOR_CONTAINER:-espresso-postgres-collector}"
coolify_network="${POSTGRES_COLLECTOR_COOLIFY_NETWORK:-coolify}"
signoz_network="${POSTGRES_COLLECTOR_SIGNOZ_NETWORK:-signoz-network}"

foundryctl_path() { command -v foundryctl 2>/dev/null || { [[ -x "$foundry_bin" ]] && printf '%s\n' "$foundry_bin"; }; }
log "foundryctl"; if path="$(foundryctl_path)"; then echo "binário encontrado: $path"; else echo "foundryctl não instalado"; fi
log "signoz"; path_is_dir_as_root "$signoz_dir" && echo "diretório encontrado: $signoz_dir" || echo "signoz não encontrado em $signoz_dir"
log "collector PostgreSQL"; path_is_dir_as_root "$collector_dir" && echo "diretório encontrado: $collector_dir" || echo "collector não encontrado em $collector_dir"
if command -v docker >/dev/null 2>&1; then
  log "containers"; as_root docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|^(signoz[-_])|^espresso-postgres-collector' || true
  log "pré-requisitos externos"; as_root docker network inspect "$coolify_network" >/dev/null 2>&1 && echo "rede Coolify encontrada: $coolify_network" || echo "rede Coolify ausente: $coolify_network"
  as_root docker network inspect "$signoz_network" >/dev/null 2>&1 && echo "rede SigNoz encontrada: $signoz_network" || echo "rede SigNoz ausente: $signoz_network"
fi
if command -v curl >/dev/null 2>&1 && curl -fsS -o /dev/null --max-time 5 "http://127.0.0.1:${signoz_ui_port}/" 2>/dev/null; then echo "UI SigNoz respondeu"; else echo "UI SigNoz não respondeu"; fi
