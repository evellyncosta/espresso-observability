#!/usr/bin/env bash

set -Eeuo pipefail
require_debian_family

signoz_dir="${SIGNOZ_DIR:-/data/signoz}"
signoz_ui_port="${SIGNOZ_UI_PORT:-8081}"
foundry_bin="${FOUNDRY_BIN_PATH:-/usr/local/bin/foundryctl}"
casting_file="$signoz_dir/casting.yaml"
minimum_memory_kb=4000000
[[ "$signoz_ui_port" =~ ^[0-9]+$ ]] || die "SIGNOZ_UI_PORT deve ser numérica"

foundryctl_path() {
  if command -v foundryctl >/dev/null 2>&1; then command -v foundryctl
  elif [[ -x "$foundry_bin" ]]; then printf '%s\n' "$foundry_bin"; else return 1; fi
}
signoz_containers_found() { as_root docker ps -a --format '{{.Names}}' | grep -E '^(signoz[-_])' >/dev/null 2>&1; }
print_signoz_containers() { as_root docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|^(signoz[-_])' || true; }
total_memory_kb() { awk '/^MemTotal:/ { print $2 }' /proc/meminfo; }
ensure_memory_available() {
  local memory_kb; memory_kb="$(total_memory_kb)"
  [[ -z "$memory_kb" || "$memory_kb" -ge "$minimum_memory_kb" ]] || die "SigNoz requer pelo menos 4GB de memória para Docker; VPS possui aproximadamente $((memory_kb / 1024))MB"
}
check_initial_ports() {
  if path_is_file_as_root "$casting_file" || signoz_containers_found; then log "instalação existente detectada; pulando preflight rígido de portas"; return; fi
  local port
  for port in "$signoz_ui_port" 4317 4318; do
    if port_in_use "$port"; then
      die "porta ${port}/tcp já está em uso antes da instalação do SigNoz"
    fi
  done
}
write_default_casting() {
  if path_is_file_as_root "$casting_file"; then log "casting.yaml existente encontrado; preservando $casting_file"; return; fi
  as_root tee "$casting_file" >/dev/null <<'YAML'
apiVersion: v1alpha1
kind: Installation
metadata:
  name: signoz
spec:
  deployment:
    flavor: compose
    mode: docker
YAML
}
ensure_ui_port_patch() {
  if as_root grep -q 'path: /services/signoz-signoz-0/ports/0' "$casting_file"; then
    as_root sed -i "\#path: /services/signoz-signoz-0/ports/0# { n; s#value: .*#value: \"${signoz_ui_port}:8080\"#; }" "$casting_file"; return
  fi
  as_root grep -q '^[[:space:]]*patches:' "$casting_file" && die "$casting_file já possui patches customizados"
  as_root tee -a "$casting_file" >/dev/null <<YAML
  patches:
    - target: "deployment/compose.yaml"
      operations:
        - op: replace
          path: /services/signoz-signoz-0/ports/0
          value: "${signoz_ui_port}:8080"
YAML
}

command -v docker >/dev/null 2>&1 || die "docker não encontrado; execute o bootstrap do Espresso Infra antes"
as_root docker compose version >/dev/null 2>&1 || die "docker compose plugin não encontrado"
service_is_active docker || die "serviço Docker não está ativo"
foundryctl="$(foundryctl_path)" || die "foundryctl não encontrado; execute install:foundryctl antes"
"$foundryctl" --help >/dev/null || die "foundryctl encontrado, mas não executa corretamente"
ensure_memory_available; as_root install -d -m 0755 "$signoz_dir"; check_initial_ports; write_default_casting; ensure_ui_port_patch
log "executando Foundry cast para provisionar SigNoz"
as_root env PATH="/usr/local/bin:/usr/bin:/bin:$PATH" "$foundryctl" cast -f "$casting_file" -p "$signoz_dir/pours"
signoz_containers_found || die "containers do SigNoz não encontrados após execução do Foundry"
print_signoz_containers; log "SigNoz provisionado ou verificado com sucesso"
