#!/usr/bin/env bash

set -Eeuo pipefail
require_debian_family
require_apt

[[ "${ENABLE_UFW:-true}" == "true" ]] || { log "ENABLE_UFW=false; configuração ignorada"; exit 0; }
[[ "${ENABLE_SIGNOZ_FIREWALL:-true}" == "true" ]] || { log "ENABLE_SIGNOZ_FIREWALL=false; configuração ignorada"; exit 0; }
signoz_ui_port="${SIGNOZ_UI_PORT:-8081}"
[[ "$signoz_ui_port" =~ ^[0-9]+$ ]] || die "SIGNOZ_UI_PORT deve ser numérica"
command -v ufw >/dev/null 2>&1 || { as_root apt-get update; apt_install ufw; }
for port in "$signoz_ui_port" 4317 4318; do as_root ufw allow "${port}/tcp" comment "SigNoz observability"; done
as_root ufw status verbose
log "configuração de firewall do SigNoz concluída"
