#!/usr/bin/env bash

set -Eeuo pipefail
require_debian_family
require_apt

install_url="${FOUNDRY_INSTALL_URL:-https://signoz.io/foundry.sh}"
foundry_version="${FOUNDRY_VERSION:-}"
foundry_bin="${FOUNDRY_BIN_PATH:-/usr/local/bin/foundryctl}"

foundryctl_path() {
  if command -v foundryctl >/dev/null 2>&1; then command -v foundryctl
  elif [[ -x "$foundry_bin" ]]; then printf '%s\n' "$foundry_bin"; else return 1; fi
}
verify_foundryctl() { "$1" --help >/dev/null; log "foundryctl disponível em $1"; }

if path="$(foundryctl_path)"; then verify_foundryctl "$path"; exit 0; fi
if ! command -v curl >/dev/null 2>&1; then as_root apt-get update; apt_install ca-certificates curl; fi
as_root install -d -m 0755 "$(dirname -- "$foundry_bin")"
install_env=(XDG_BIN_HOME="$(dirname -- "$foundry_bin")")
[[ -n "$foundry_version" ]] && install_env+=(FOUNDRY_VERSION="$foundry_version")
curl -fsSL "$install_url" | as_root env "${install_env[@]}" bash
path="$(foundryctl_path)" || die "foundryctl não encontrado após instalação"
verify_foundryctl "$path"
log "instalação do Foundry/foundryctl concluída"
