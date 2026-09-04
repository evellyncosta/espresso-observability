# Collector PostgreSQL

Voltar para o [README](../README.md). Consulte [SigNoz](signoz.md) e [Integração com infra](infra-integration.md).

O collector é uma stack Compose própria que lê métricas do PostgreSQL gerenciado pelo Coolify na rede `coolify` e as envia por OTLP para `signoz-ingester:4317` na rede `signoz-network`.

```bash
task install:postgres-collector
task status
```

O diretório operacional padrão é `/data/signoz-integrations/postgres-collector`. A senha do usuário monitor fica apenas no `.env` privado da VPS; ela nunca é versionada ou mostrada pela task. A remoção padrão do collector preserva a role `espresso_otel_monitor`; defina `DESTROY_POSTGRES_MONITOR_USER=true` para removê-la explicitamente.
