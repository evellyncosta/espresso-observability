# Arquitetura

Voltar para o [README](../README.md).

```text
Coolify / rede coolify                         Observabilidade / rede signoz-network
PostgreSQL da aplicação --> collector PostgreSQL --------------------> signoz-ingester --> SigNoz
Aplicação (OTLP) --------> collector OTLP dedicado da aplicação -----> signoz-ingester --> SigNoz
```

Cada collector é independente tanto do Compose do Coolify quanto da stack gerada pelo Foundry. O collector da aplicação recebe métricas e traces OTLP pelas portas internas `4317` (gRPC) e `4318` (HTTP), sem publicação de portas na VPS. A destruição deste repositório remove a plataforma de observabilidade e não altera Docker base, Coolify, PostgreSQL da aplicação ou seus dados.
