#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
log() { echo "[remote] $*"; }
die() { echo "[remote] Erro: $*" >&2; exit 1; }
require_env() { [[ -n "${!1:-}" ]] || die "variável obrigatória ausente: $1"; }
shell_quote() { printf "%q" "$1"; }

load_env_file() {
  if [[ -f "$repo_dir/.env" ]]; then set -a; source "$repo_dir/.env"; set +a; fi
}
validate_local_env() {
  require_env SERVER_HOST; require_env SERVER_USER; require_env SSH_KEY_PATH
  [[ -r "$SSH_KEY_PATH" ]] || die "SSH_KEY_PATH não aponta para um arquivo legível: $SSH_KEY_PATH"
  SSH_PORT="${SSH_PORT:-22}"; [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || die "SSH_PORT deve ser numérica"
  ENABLE_UFW="${ENABLE_UFW:-true}"; ENABLE_SIGNOZ_FIREWALL="${ENABLE_SIGNOZ_FIREWALL:-true}"
  FOUNDRY_INSTALL_URL="${FOUNDRY_INSTALL_URL:-https://signoz.io/foundry.sh}"; FOUNDRY_VERSION="${FOUNDRY_VERSION:-}"; FOUNDRY_BIN_PATH="${FOUNDRY_BIN_PATH:-/usr/local/bin/foundryctl}"
  SIGNOZ_DIR="${SIGNOZ_DIR:-/data/signoz}"; SIGNOZ_UI_PORT="${SIGNOZ_UI_PORT:-8081}"; [[ "$SIGNOZ_UI_PORT" =~ ^[0-9]+$ ]] || die "SIGNOZ_UI_PORT deve ser numérica"
  POSTGRES_COLLECTOR_ENABLED="${POSTGRES_COLLECTOR_ENABLED:-true}"; POSTGRES_COLLECTOR_DIR="${POSTGRES_COLLECTOR_DIR:-/data/signoz-integrations/postgres-collector}"; POSTGRES_COLLECTOR_IMAGE="${POSTGRES_COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:0.139.0}"; POSTGRES_COLLECTOR_CONTAINER="${POSTGRES_COLLECTOR_CONTAINER:-espresso-postgres-collector}"
  POSTGRES_COLLECTOR_COOLIFY_NETWORK="${POSTGRES_COLLECTOR_COOLIFY_NETWORK:-coolify}"; POSTGRES_COLLECTOR_SIGNOZ_NETWORK="${POSTGRES_COLLECTOR_SIGNOZ_NETWORK:-signoz-network}"; POSTGRES_COLLECTOR_SIGNOZ_ENDPOINT="${POSTGRES_COLLECTOR_SIGNOZ_ENDPOINT:-signoz-ingester:4317}"; POSTGRES_COLLECTOR_COOLIFY_PROJECT="${POSTGRES_COLLECTOR_COOLIFY_PROJECT:-espresso}"; POSTGRES_COLLECTOR_POSTGRES_CONTAINER="${POSTGRES_COLLECTOR_POSTGRES_CONTAINER:-}"; POSTGRES_COLLECTOR_POSTGRES_HOST="${POSTGRES_COLLECTOR_POSTGRES_HOST:-}"; POSTGRES_COLLECTOR_POSTGRES_PORT="${POSTGRES_COLLECTOR_POSTGRES_PORT:-5432}"; POSTGRES_COLLECTOR_POSTGRES_DB="${POSTGRES_COLLECTOR_POSTGRES_DB:-}"; POSTGRES_MONITOR_USER="${POSTGRES_MONITOR_USER:-espresso_otel_monitor}"; POSTGRES_COLLECTOR_INTERVAL="${POSTGRES_COLLECTOR_INTERVAL:-30s}"; POSTGRES_COLLECTOR_ENVIRONMENT="${POSTGRES_COLLECTOR_ENVIRONMENT:-production}"; DESTROY_POSTGRES_MONITOR_USER="${DESTROY_POSTGRES_MONITOR_USER:-false}"
  [[ "$POSTGRES_COLLECTOR_POSTGRES_PORT" =~ ^[0-9]+$ ]] || die "POSTGRES_COLLECTOR_POSTGRES_PORT deve ser numérica"
}
ssh_target() { printf '%s@%s' "$SERVER_USER" "$SERVER_HOST"; }
ssh_base_args() { printf '%s\n' -i "$SSH_KEY_PATH" -p "$SSH_PORT" -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ServerAliveCountMax=3; }
remote_env_prefix() {
  local names=(ENABLE_UFW ENABLE_SIGNOZ_FIREWALL FOUNDRY_INSTALL_URL FOUNDRY_VERSION FOUNDRY_BIN_PATH SIGNOZ_DIR SIGNOZ_UI_PORT POSTGRES_COLLECTOR_ENABLED POSTGRES_COLLECTOR_DIR POSTGRES_COLLECTOR_IMAGE POSTGRES_COLLECTOR_CONTAINER POSTGRES_COLLECTOR_COOLIFY_NETWORK POSTGRES_COLLECTOR_SIGNOZ_NETWORK POSTGRES_COLLECTOR_SIGNOZ_ENDPOINT POSTGRES_COLLECTOR_COOLIFY_PROJECT POSTGRES_COLLECTOR_POSTGRES_CONTAINER POSTGRES_COLLECTOR_POSTGRES_HOST POSTGRES_COLLECTOR_POSTGRES_PORT POSTGRES_COLLECTOR_POSTGRES_DB POSTGRES_MONITOR_USER POSTGRES_COLLECTOR_INTERVAL POSTGRES_COLLECTOR_ENVIRONMENT DESTROY_POSTGRES_MONITOR_USER)
  local name; for name in "${names[@]}"; do printf '%s=%s ' "$name" "$(shell_quote "${!name}")"; done
}
run_ssh_command() { local command="$1"; mapfile -t args < <(ssh_base_args); ssh "${args[@]}" "$(ssh_target)" "$command"; }
run_remote_script() {
  local script_name="$1" script_path="$script_dir/$1.sh" common_path="$script_dir/server-lib.sh" combined_script
  [[ -f "$script_path" ]] || die "script não encontrado: $script_path"; [[ -f "$common_path" ]] || die "biblioteca remota não encontrada: $common_path"
  combined_script="$(mktemp "${TMPDIR:-/tmp}/espresso-observability.XXXXXX")"; trap 'rm -f -- "${combined_script:-}"' RETURN
  sed '1{/^#!/d;}' "$common_path" > "$combined_script"; sed '1{/^#!/d;}' "$script_path" >> "$combined_script"
  mapfile -t args < <(ssh_base_args); log "executando scripts/$script_name.sh em $(ssh_target)"; ssh "${args[@]}" "$(ssh_target)" "$(remote_env_prefix) bash -s" < "$combined_script"
}
main() {
  local action="${1:-}"; shift || true; load_env_file; validate_local_env
  case "$action" in
    preflight) log "validando conectividade SSH com $(ssh_target)"; run_ssh_command true; log "preflight concluído" ;;
    foundryctl|signoz|postgres-collector|signoz-firewall|observability-status|observability-destroy) run_remote_script "$action" ;;
    *) die "ação inválida: ${action:-<vazia>}" ;;
  esac
}
main "$@"
