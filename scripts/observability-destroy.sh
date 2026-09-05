#!/usr/bin/env bash

set -Eeuo pipefail
require_debian_family

signoz_dir="${SIGNOZ_DIR:-/data/signoz}"
collector_dir="${POSTGRES_COLLECTOR_DIR:-/data/signoz-integrations/postgres-collector}"
collector_container="${POSTGRES_COLLECTOR_CONTAINER:-espresso-postgres-collector}"
application_collector_dir="${APPLICATION_OTEL_COLLECTOR_DIR:-/data/signoz-integrations/application-otel-collector}"
application_collector_container="${APPLICATION_OTEL_COLLECTOR_CONTAINER:-espresso-application-otel-collector}"
signoz_network="${POSTGRES_COLLECTOR_SIGNOZ_NETWORK:-signoz-network}"
signoz_ui_port="${SIGNOZ_UI_PORT:-8081}"
remove_monitor_user="${DESTROY_POSTGRES_MONITOR_USER:-false}"

safe_operational_dir() {
  local path="$1"
  [[ "$path" == /data/* && "$path" != /data/ && "$path" != /data ]] || die "diretório operacional inseguro: $path"
}
safe_operational_dir "$signoz_dir"
safe_operational_dir "$collector_dir"
safe_operational_dir "$application_collector_dir"
[[ "$signoz_ui_port" =~ ^[0-9]+$ ]] || die "SIGNOZ_UI_PORT deve ser numérica"
[[ "$remove_monitor_user" == true || "$remove_monitor_user" == false ]] || die "DESTROY_POSTGRES_MONITOR_USER deve ser true ou false"

read_collector_env_value() {
  local key="$1" file="$collector_dir/.env"
  path_is_file_as_root "$file" || return 1
  as_root awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; found=1; exit } END { exit found ? 0 : 1 }' "$file"
}
drop_monitor_role() {
  local role container admin_user admin_db
  role="$(read_collector_env_value POSTGRES_MONITOR_USER || printf '%s' "${POSTGRES_MONITOR_USER:-espresso_otel_monitor}")"
  [[ "$role" =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]] || die "usuário monitor inválido no ambiente operacional"
  container="${POSTGRES_COLLECTOR_POSTGRES_CONTAINER:-}"
  [[ -n "$container" ]] || container="$(read_collector_env_value POSTGRES_DB_HOST || true)"
  [[ -n "$container" ]] || die "não foi possível identificar o container PostgreSQL para remover a role"
  as_root docker inspect "$container" >/dev/null 2>&1 || die "o alvo para remover a role não é um container Docker local: $container"
  mapfile -t admin_env < <(as_root docker exec "$container" sh -lc 'printf "%s\n%s\n" "${POSTGRES_USER:-postgres}" "${POSTGRES_DB:-postgres}"')
  admin_user="${admin_env[0]:-postgres}"; admin_db="${admin_env[1]:-postgres}"
  log "removendo role de monitoramento PostgreSQL: $role"
  as_root docker exec -i -e MONITOR_USER="$role" "$container" sh -s -- "$admin_user" "$admin_db" <<'SH'
set -Eeuo pipefail
psql -v ON_ERROR_STOP=1 -v monitor_user="$MONITOR_USER" -U "$1" -d "$2" <<'SQL'
SELECT format('DROP ROLE %I', :'monitor_user')
WHERE EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = :'monitor_user')
\gexec
SQL
SH
}

compose_down_if_signoz() {
  local compose_file="$1"
  as_root grep -Eq '(^|[^[:alnum:]])signoz([^[:alnum:]]|$)' "$compose_file" || die "compose fora do escopo SigNoz: $compose_file"
  log "removendo stack SigNoz declarada em $compose_file"
  as_root docker compose -f "$compose_file" down --volumes --remove-orphans
}

if command -v docker >/dev/null 2>&1; then
  if path_is_file_as_root "$application_collector_dir/docker-compose.yml"; then
    log "removendo collector OTLP da aplicação"
    as_root docker compose -f "$application_collector_dir/docker-compose.yml" down --volumes --remove-orphans || die "falha ao remover collector OTLP da aplicação declarado"
  elif as_root docker inspect "$application_collector_container" >/dev/null 2>&1; then
    log "removendo container do collector OTLP da aplicação identificado: $application_collector_container"
    as_root docker rm -f "$application_collector_container"
  fi

  if path_is_file_as_root "$collector_dir/docker-compose.yml"; then
    log "removendo collector PostgreSQL"
    as_root docker compose -f "$collector_dir/docker-compose.yml" down --volumes --remove-orphans || die "falha ao remover collector declarado"
  elif as_root docker inspect "$collector_container" >/dev/null 2>&1; then
    log "removendo container de collector identificado: $collector_container"
    as_root docker rm -f "$collector_container"
  fi

  if path_is_dir_as_root "$signoz_dir/pours"; then
    while IFS= read -r -d '' compose_file; do compose_down_if_signoz "$compose_file"; done < <(as_root find "$signoz_dir/pours" -type f \( -name compose.yaml -o -name compose.yml -o -name docker-compose.yaml -o -name docker-compose.yml \) -print0)
  fi

  mapfile -t residual_containers < <(as_root docker ps -aq --filter 'name=^/signoz[-_]' --format '{{.ID}}')
  if ((${#residual_containers[@]})); then
    log "removendo containers residuais com prefixo signoz"
    as_root docker rm -f "${residual_containers[@]}"
  fi

  mapfile -t signoz_volumes < <(as_root docker volume ls -q --filter 'label=com.docker.compose.project=signoz')
  if ((${#signoz_volumes[@]})); then
    log "removendo volumes nomeados da stack compose signoz"
    as_root docker volume rm "${signoz_volumes[@]}"
  fi

  if as_root docker network inspect "$signoz_network" >/dev/null 2>&1; then
    attached="$(as_root docker network inspect -f '{{range $id, $c := .Containers}}{{$c.Name}} {{end}}' "$signoz_network")"
    [[ -z "$attached" ]] || die "rede $signoz_network ainda possui containers fora do escopo: $attached"
    log "removendo rede vazia $signoz_network"
    as_root docker network rm "$signoz_network"
  fi
fi

if command -v ufw >/dev/null 2>&1; then
  mapfile -t ufw_rules < <(as_root ufw status numbered | sed -nE '/SigNoz observability$/ s/^[[:space:]]*\[[[:space:]]*([0-9]+)\].*/\1/p' | sort -rn)
  for rule in "${ufw_rules[@]}"; do
    log "removendo regra UFW #$rule com comentário SigNoz observability"
    as_root ufw --force delete "$rule"
  done
fi

if [[ "$remove_monitor_user" == true ]]; then drop_monitor_role; fi
if path_is_dir_as_root "$application_collector_dir"; then log "removendo diretório operacional do collector OTLP da aplicação"; as_root rm -rf -- "$application_collector_dir"; fi
if path_is_dir_as_root "$collector_dir"; then log "removendo diretório operacional do collector"; as_root rm -rf -- "$collector_dir"; fi
if path_is_dir_as_root "$signoz_dir"; then log "removendo diretório operacional do SigNoz"; as_root rm -rf -- "$signoz_dir"; fi

if [[ "$remove_monitor_user" == true ]]; then log "destruição concluída com remoção explícita da role de monitoramento"; else log "destruição concluída; a role de monitoramento PostgreSQL foi preservada"; fi
