#!/usr/bin/env bash

set -Eeuo pipefail
require_debian_family

enabled="${POSTGRES_COLLECTOR_ENABLED:-true}"
dir="${POSTGRES_COLLECTOR_DIR:-/data/signoz-integrations/postgres-collector}"
image="${POSTGRES_COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:0.139.0}"
container_name="${POSTGRES_COLLECTOR_CONTAINER:-espresso-postgres-collector}"
coolify_network="${POSTGRES_COLLECTOR_COOLIFY_NETWORK:-coolify}"
signoz_network="${POSTGRES_COLLECTOR_SIGNOZ_NETWORK:-signoz-network}"
signoz_endpoint="${POSTGRES_COLLECTOR_SIGNOZ_ENDPOINT:-signoz-ingester:4317}"
coolify_project="${POSTGRES_COLLECTOR_COOLIFY_PROJECT:-espresso}"
postgres_container="${POSTGRES_COLLECTOR_POSTGRES_CONTAINER:-}"
postgres_host="${POSTGRES_COLLECTOR_POSTGRES_HOST:-}"
postgres_port="${POSTGRES_COLLECTOR_POSTGRES_PORT:-5432}"
postgres_db="${POSTGRES_COLLECTOR_POSTGRES_DB:-}"
monitor_user="${POSTGRES_MONITOR_USER:-espresso_otel_monitor}"
interval="${POSTGRES_COLLECTOR_INTERVAL:-30s}"
environment="${POSTGRES_COLLECTOR_ENVIRONMENT:-production}"
env_file="$dir/.env"; config_file="$dir/collector.yaml"; compose_file="$dir/docker-compose.yml"

[[ "$enabled" == true ]] || { log "POSTGRES_COLLECTOR_ENABLED=false; collector ignorado"; exit 0; }
[[ "$postgres_port" =~ ^[0-9]+$ ]] || die "POSTGRES_COLLECTOR_POSTGRES_PORT deve ser numérica"
[[ "$monitor_user" =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]] || die "POSTGRES_MONITOR_USER deve ser identificador PostgreSQL simples"
command -v docker >/dev/null 2>&1 || die "docker não encontrado; execute o bootstrap do Espresso Infra antes"
as_root docker compose version >/dev/null 2>&1 || die "docker compose plugin não encontrado"
service_is_active docker || die "serviço Docker não está ativo"
as_root docker network inspect "$coolify_network" >/dev/null 2>&1 || die "rede Docker não encontrada: $coolify_network"
as_root docker network inspect "$signoz_network" >/dev/null 2>&1 || die "rede Docker não encontrada: $signoz_network"

resolve_postgres_container() {
  if [[ -n "$postgres_container" ]]; then
    as_root docker inspect "$postgres_container" >/dev/null 2>&1 || die "container PostgreSQL informado não encontrado: $postgres_container"
    printf '%s\n' "$postgres_container"; return
  fi
  local matches count
  matches="$(as_root docker ps --filter 'label=coolify.managed=true' --filter 'label=coolify.database.subType=standalone-postgresql' --filter "label=coolify.projectName=$coolify_project" --format '{{.Names}}')"
  count="$(printf '%s\n' "$matches" | awk 'NF {n++} END {print n+0}')"
  [[ "$count" == 1 ]] || die "container PostgreSQL da aplicação ambíguo ou ausente; configure POSTGRES_COLLECTOR_POSTGRES_CONTAINER"
  printf '%s\n' "$matches" | awk 'NF {print; exit}'
}
read_env_value() { path_is_file_as_root "$env_file" && as_root awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$env_file"; }
generate_password() { command -v openssl >/dev/null 2>&1 && openssl rand -hex 32 || od -An -N32 -tx1 /dev/urandom | tr -d ' \n'; }
target="$(resolve_postgres_container)"
mapfile -t admin_env < <(as_root docker exec "$target" sh -lc 'printf "%s\n%s\n" "${POSTGRES_USER:-postgres}" "${POSTGRES_DB:-postgres}"')
admin_user="${admin_env[0]:-postgres}"; admin_db="${admin_env[1]:-postgres}"
[[ -n "$postgres_db" ]] || postgres_db="$admin_db"; [[ -n "$postgres_host" ]] || postgres_host="$target"
as_root install -d -m 0700 "$dir"
password="$(read_env_value POSTGRES_MONITOR_PASSWORD || true)"; [[ -n "$password" ]] || password="$(generate_password)"

as_root tee "$env_file" >/dev/null <<ENV
POSTGRES_MONITOR_USER=$monitor_user
POSTGRES_MONITOR_PASSWORD=$password
POSTGRES_DB_HOST=$postgres_host
POSTGRES_DB_PORT=$postgres_port
POSTGRES_DB_NAME=$postgres_db
POSTGRES_COLLECTOR_IMAGE=$image
POSTGRES_COLLECTOR_CONTAINER=$container_name
POSTGRES_COLLECTOR_COOLIFY_NETWORK=$coolify_network
POSTGRES_COLLECTOR_SIGNOZ_NETWORK=$signoz_network
SIGNOZ_OTLP_ENDPOINT=$signoz_endpoint
POSTGRES_COLLECTOR_INTERVAL=$interval
POSTGRES_COLLECTOR_ENVIRONMENT=$environment
ENV
as_root chmod 0600 "$env_file"

as_root docker exec -i -e MONITOR_USER="$monitor_user" -e MONITOR_PASSWORD="$password" -e MONITOR_DB="$postgres_db" "$target" sh -s -- "$admin_user" "$admin_db" <<'SH'
set -Eeuo pipefail
export PGOPTIONS="-c espresso.monitor_user=${MONITOR_USER} -c espresso.monitor_password=${MONITOR_PASSWORD} -c espresso.monitor_db=${MONITOR_DB}"
psql -v ON_ERROR_STOP=1 -U "$1" -d "$2" <<'SQL'
DO $do$
DECLARE u text := current_setting('espresso.monitor_user'); p text := current_setting('espresso.monitor_password'); d text := current_setting('espresso.monitor_db');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = u) THEN EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', u, p); ELSE EXECUTE format('ALTER ROLE %I LOGIN PASSWORD %L', u, p); END IF;
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', d, u); EXECUTE format('GRANT SELECT ON pg_catalog.pg_stat_database TO %I', u);
END $do$;
SQL
SH

as_root tee "$config_file" >/dev/null <<'YAML'
receivers:
  postgresql/espresso:
    endpoint: ${env:POSTGRES_DB_HOST}:${env:POSTGRES_DB_PORT}
    username: ${env:POSTGRES_MONITOR_USER}
    password: ${env:POSTGRES_MONITOR_PASSWORD}
    databases:
      - ${env:POSTGRES_DB_NAME}
    collection_interval: ${env:POSTGRES_COLLECTOR_INTERVAL}
    tls: { insecure: true }
processors: { batch: {} }
exporters:
  otlp/signoz:
    endpoint: ${env:SIGNOZ_OTLP_ENDPOINT}
    tls: { insecure: true }
service:
  pipelines:
    metrics/postgres: { receivers: [postgresql/espresso], processors: [batch], exporters: [otlp/signoz] }
YAML
as_root tee "$compose_file" >/dev/null <<'YAML'
name: espresso-postgres-collector
services:
  postgres-collector:
    container_name: ${POSTGRES_COLLECTOR_CONTAINER}
    image: ${POSTGRES_COLLECTOR_IMAGE}
    command:
      - --config=/etc/otelcol-contrib/collector.yaml
      - --feature-gates=receiver.postgresql.separateSchemaAttr
    env_file:
      - .env
    restart: unless-stopped
    volumes:
      - ./collector.yaml:/etc/otelcol-contrib/collector.yaml:ro
    networks:
      coolify:
      signoz:
networks:
  coolify:
    external: true
    name: ${POSTGRES_COLLECTOR_COOLIFY_NETWORK}
  signoz:
    external: true
    name: ${POSTGRES_COLLECTOR_SIGNOZ_NETWORK}
YAML
as_root docker compose --env-file "$env_file" -f "$compose_file" config --quiet
as_root docker compose --env-file "$env_file" -f "$compose_file" up -d
log "collector PostgreSQL provisionado ou verificado com sucesso"
