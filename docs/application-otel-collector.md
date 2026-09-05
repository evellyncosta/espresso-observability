# Collector OTLP da aplicação

Voltar para o [README](../README.md). Consulte também [Arquitetura](architecture.md), [Operação](operations.md) e [Integração com infra](infra-integration.md).

O collector OTLP da aplicação é uma stack Compose própria conectada às redes Docker `coolify` e `signoz-network`. Ele recebe métricas e traces OTLP enviados pela aplicação e os encaminha ao `signoz-ingester:4317`; não realiza coleta por polling nem publica portas na VPS.

```bash
task install:application-otel-collector
task status
```

O diretório operacional padrão é `/data/signoz-integrations/application-otel-collector`. O collector usa o hostname interno `espresso-application-otel-collector` na rede `coolify`, salvo se `APPLICATION_OTEL_COLLECTOR_CONTAINER` for personalizado.

## Configuração da aplicação no Coolify

Após instalar o collector, configure o SDK OpenTelemetry da aplicação durante o deploy no Coolify. Use uma das opções abaixo, conforme o protocolo suportado pelo SDK:

```bash
# OTLP gRPC
OTEL_EXPORTER_OTLP_ENDPOINT=espresso-application-otel-collector:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

```bash
# OTLP HTTP/protobuf
OTEL_EXPORTER_OTLP_ENDPOINT=http://espresso-application-otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

O collector aplica `service.name` a partir de `APPLICATION_OTEL_SERVICE_NAME` e fixa `deployment.environment.name=production`. Defina o primeiro com o nome canônico da aplicação antes da instalação; não é necessário nem recomendado que a aplicação o sobrescreva. Essas variáveis de aplicação são configuradas no Coolify e estão fora do lifecycle deste repositório.

Depois do deploy, gere tráfego e confirme no SigNoz que os traces e as métricas aparecem no serviço configurado, filtrados pelo ambiente `production`.
