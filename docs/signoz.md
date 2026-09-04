# SigNoz

Voltar para o [README](../README.md). Consulte também [Operação](operations.md) e [Integração com infra](infra-integration.md).

SigNoz é provisionado por Foundry/foundryctl fora do lifecycle do Coolify.

```bash
task setup
task status
task destroy
```

O diretório padrão é `/data/signoz`; a UI usa `http://<SERVER_HOST>:8081`, OTLP gRPC `4317` e OTLP HTTP `4318`. A instalação exige pelo menos 4 GB de memória e abre essas portas apenas quando `ENABLE_SIGNOZ_FIREWALL=true`.

Os arquivos gerados em `pours/` não devem ser editados manualmente. Dashboards, alertas, retenção, API keys e instrumentação da aplicação não pertencem a este repositório.
