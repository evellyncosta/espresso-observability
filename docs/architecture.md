# Arquitetura

Voltar para o [README](../README.md).

```text
Coolify / rede coolify             Observabilidade / rede signoz-network
PostgreSQL da aplicação --> collector PostgreSQL --> signoz-ingester --> SigNoz
```

O collector é independente tanto do Compose do Coolify quanto da stack gerada pelo Foundry. A destruição deste repositório remove a plataforma de observabilidade e não altera Docker base, Coolify, PostgreSQL da aplicação ou seus dados.
