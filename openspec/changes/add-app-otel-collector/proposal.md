## Why

A aplicação gerenciada pelo Coolify ainda não tem um caminho de telemetria OTLP provisionado para o SigNoz. Um collector dedicado permite encaminhar suas métricas e traces na rede Docker interna, sem expor um endpoint de ingestão publicamente nem acoplar a observabilidade ao lifecycle do deploy da aplicação.

## What Changes

- Provisionar um OpenTelemetry Collector dedicado para receber métricas e traces OTLP da aplicação na rede `coolify` e exportá-los para o SigNoz na rede `signoz-network`.
- Definir identificação estável do serviço e do único ambiente suportado (`production`) nos dados encaminhados.
- Adicionar comandos, verificação de estado, remoção segura e documentação para o collector da aplicação.
- Manter o collector PostgreSQL, a aplicação e o Coolify fora do escopo de alteração direta.

## Capabilities

### New Capabilities

- `application-otel-collector`: Provisiona, reconcilia e remove um collector OTLP dedicado que encaminha métricas e traces da aplicação do Coolify ao SigNoz com atributos de serviço e ambiente.

### Modified Capabilities

- Nenhuma.

## Impact

- Scripts remotos, tarefas Taskfile e variáveis de ambiente deste repositório.
- Uma stack Compose operacional independente em `/data/signoz-integrations` e conexões às redes Docker `coolify` e `signoz-network`.
- A configuração OTLP da aplicação no Coolify passa a apontar para o receiver interno do collector, mas a alteração dessa configuração permanece uma ação operacional externa a este repositório.
