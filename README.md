# Espresso Observability

Provisiona e remove a plataforma de observabilidade do lab Espresso: SigNoz, Foundry/foundryctl e o collector PostgreSQL. Este repositório é independente do lifecycle do Coolify.

O [Espresso Infra](https://github.com/evellyncosta/espresso-infra) prepara VPS, SSH, Docker, firewall base e Coolify. A aplicação e o banco continuam gerenciados pelo Coolify.

## Início rápido

```bash
cp .env.example .env
# preencher SERVER_HOST, SERVER_USER e SSH_KEY_PATH
task preflight
task setup
task install:postgres-collector
task install:application-otel-collector
```

Para remover a plataforma:

```bash
task destroy
```

`destroy` remove somente recursos de observabilidade. Por padrão, a role de monitoramento PostgreSQL é preservada; use `DESTROY_POSTGRES_MONITOR_USER=true` somente quando quiser removê-la explicitamente.

## Documentação

- [Arquitetura](docs/architecture.md)
- [SigNoz](docs/signoz.md)
- [Collector PostgreSQL](docs/postgres-collector.md)
- [Collector OTLP da aplicação](docs/application-otel-collector.md)
- [Operação](docs/operations.md)
- [Integração com infra](docs/infra-integration.md)
