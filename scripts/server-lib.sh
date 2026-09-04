#!/usr/bin/env bash

set -Eeuo pipefail

log() { echo "[observability] $*"; }
die() { echo "[observability] Erro: $*" >&2; exit 1; }

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else
    command -v sudo >/dev/null 2>&1 || die "sudo é necessário para executar: $*"
    sudo -n "$@"
  fi
}

apt_install() { as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
require_debian_family() {
  local os_release_file="${OBSERVABILITY_OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r "$os_release_file" ]] || die "$os_release_file não encontrado"
  # shellcheck disable=SC1090
  source "$os_release_file"
  case "${ID:-}:${VERSION_ID:-}" in
    debian:12|ubuntu:22.04|ubuntu:24.04) log "sistema suportado detectado: ${PRETTY_NAME:-$ID $VERSION_ID}" ;;
    *) die "sistema não suportado: ${PRETTY_NAME:-${ID:-desconhecido} ${VERSION_ID:-}}" ;;
  esac
}
require_apt() { command -v apt-get >/dev/null 2>&1 || die "apt-get não encontrado"; }
service_is_active() { systemctl is-active --quiet "$1"; }
path_is_dir_as_root() { as_root test -d "$1"; }
path_is_file_as_root() { as_root test -f "$1"; }
port_in_use() {
  local port="$1"
  command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :$port )" | awk 'NR > 1 { found = 1 } END { exit found ? 0 : 1 }'
}
