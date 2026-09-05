#!/usr/bin/env bash

set -Eeuo pipefail
require_debian_family

enabled="${APPLICATION_OTEL_COLLECTOR_ENABLED:-true}"
dir="${APPLICATION_OTEL_COLLECTOR_DIR:-/data/signoz-integrations/application-otel-collector}"
image="${APPLICATION_OTEL_COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:0.139.0}"
container_name="${APPLICATION_OTEL_COLLECTOR_CONTAINER:-espresso-application-otel-collector}"
coolify_network="${APPLICATION_OTEL_COLLECTOR_COOLIFY_NETWORK:-coolify}"
signoz_network="${APPLICATION_OTEL_COLLECTOR_SIGNOZ_NETWORK:-signoz-network}"
signoz_endpoint="${APPLICATION_OTEL_COLLECTOR_SIGNOZ_ENDPOINT:-signoz-ingester:4317}"
service_name="${APPLICATION_OTEL_SERVICE_NAME:-espresso}"
environment="${APPLICATION_OTEL_ENVIRONMENT:-production}"
env_file="$dir/.env"; config_file="$dir/collector.yaml"; compose_file="$dir/docker-compose.yml"

[[ "$enabled" == true ]] || { log "APPLICATION_OTEL_COLLECTOR_ENABLED=false; collector ignorado"; exit 0; }
[[ "$dir" == /data/* && "$dir" != /data/ && "$dir" != /data ]] || die "diretório operacional inseguro: $dir"
[[ "$container_name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || die "APPLICATION_OTEL_COLLECTOR_CONTAINER inválido"
[[ "$service_name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || die "APPLICATION_OTEL_SERVICE_NAME inválido"
[[ "$environment" == production ]] || die "APPLICATION_OTEL_ENVIRONMENT deve ser production"
command -v docker >/dev/null 2>&1 || die "docker não encontrado; execute o bootstrap do Espresso Infra antes"
as_root docker compose version >/dev/null 2>&1 || die "docker compose plugin não encontrado"
service_is_active docker || die "serviço Docker não está ativo"
as_root docker network inspect "$coolify_network" >/dev/null 2>&1 || die "rede Docker não encontrada: $coolify_network"
as_root docker network inspect "$signoz_network" >/dev/null 2>&1 || die "rede Docker não encontrada: $signoz_network"

as_root install -d -m 0700 "$dir"
as_root tee "$env_file" >/dev/null <<ENV
APPLICATION_OTEL_COLLECTOR_IMAGE=$image
APPLICATION_OTEL_COLLECTOR_CONTAINER=$container_name
APPLICATION_OTEL_COLLECTOR_COOLIFY_NETWORK=$coolify_network
APPLICATION_OTEL_COLLECTOR_SIGNOZ_NETWORK=$signoz_network
APPLICATION_OTEL_COLLECTOR_SIGNOZ_ENDPOINT=$signoz_endpoint
APPLICATION_OTEL_SERVICE_NAME=$service_name
APPLICATION_OTEL_ENVIRONMENT=$environment
ENV
as_root chmod 0600 "$env_file"

as_root tee "$config_file" >/dev/null <<'YAML'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
processors:
  resource/application:
    attributes:
      - key: service.name
        value: ${env:APPLICATION_OTEL_SERVICE_NAME}
        action: upsert
      - key: deployment.environment.name
        value: ${env:APPLICATION_OTEL_ENVIRONMENT}
        action: upsert
  batch: {}
exporters:
  otlp/signoz:
    endpoint: ${env:APPLICATION_OTEL_COLLECTOR_SIGNOZ_ENDPOINT}
    tls:
      insecure: true
service:
  pipelines:
    metrics/application:
      receivers: [otlp]
      processors: [resource/application, batch]
      exporters: [otlp/signoz]
    traces/application:
      receivers: [otlp]
      processors: [resource/application, batch]
      exporters: [otlp/signoz]
YAML
as_root tee "$compose_file" >/dev/null <<'YAML'
name: espresso-application-otel-collector
services:
  application-otel-collector:
    container_name: ${APPLICATION_OTEL_COLLECTOR_CONTAINER}
    image: ${APPLICATION_OTEL_COLLECTOR_IMAGE}
    command:
      - --config=/etc/otelcol-contrib/collector.yaml
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
    name: ${APPLICATION_OTEL_COLLECTOR_COOLIFY_NETWORK}
  signoz:
    external: true
    name: ${APPLICATION_OTEL_COLLECTOR_SIGNOZ_NETWORK}
YAML
as_root docker compose --env-file "$env_file" -f "$compose_file" config --quiet
as_root docker compose --env-file "$env_file" -f "$compose_file" up -d --force-recreate
log "collector OTLP da aplicação provisionado ou verificado com sucesso"
