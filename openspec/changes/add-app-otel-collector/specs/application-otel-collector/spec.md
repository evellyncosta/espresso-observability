## Purpose

Disponibilizar encaminhamento OTLP interno para que métricas e traces da
aplicação gerenciada pelo Coolify sejam associados ao serviço correto no SigNoz.

## ADDED Requirements

### Requirement: Collector dedicado para telemetria da aplicação
O sistema SHALL provisionar e reconciliar um collector OpenTelemetry independente que receba métricas e traces OTLP da aplicação pela rede Docker do Coolify e os encaminhe ao SigNoz pela rede de observabilidade. O collector SHALL usar exclusivamente comunicação interna entre as redes e não SHALL publicar suas portas de ingestão na interface pública da VPS.

#### Scenario: Provisionamento com as redes disponíveis
- **WHEN** as redes Docker configuradas do Coolify e do SigNoz existem e o comando de instalação é executado
- **THEN** um collector dedicado em execução fica acessível à aplicação na rede do Coolify e encaminha métricas e traces por OTLP ao SigNoz

#### Scenario: Rede necessária ausente
- **WHEN** uma das redes Docker exigidas não existe durante o provisionamento
- **THEN** o provisionamento falha com uma mensagem que identifica a rede ausente sem criar uma configuração parcial do collector

### Requirement: Identidade de serviço e ambiente na telemetria
O sistema SHALL anexar à telemetria encaminhada um `service.name` configurável e estável e `deployment.environment.name=production`. Esses atributos SHALL permitir que métricas e traces sejam associados e filtrados pelo serviço correspondente na guia Services do SigNoz.

#### Scenario: Métrica recebida da aplicação
- **WHEN** o collector recebe uma métrica OTLP da aplicação
- **THEN** a métrica exportada ao SigNoz contém o nome de serviço configurado e o ambiente `production`

#### Scenario: Trace recebido da aplicação
- **WHEN** o collector recebe um trace OTLP da aplicação
- **THEN** o trace exportado ao SigNoz contém o nome de serviço configurado e o ambiente `production`, permitindo que o serviço seja exibido em Services

### Requirement: Operação segura do collector da aplicação
O sistema SHALL oferecer comandos para instalar ou reconciliar, inspecionar estado e remover o collector da aplicação. A remoção SHALL limitar-se aos recursos operacionais do collector e não SHALL remover a aplicação, o Coolify, o SigNoz ou recursos do collector PostgreSQL.

#### Scenario: Consulta de estado
- **WHEN** o comando de estado é executado
- **THEN** ele informa se o diretório operacional, o container do collector e as redes necessárias estão presentes sem exibir segredos

#### Scenario: Remoção da observabilidade
- **WHEN** o comando de remoção é executado
- **THEN** os recursos do collector da aplicação são removidos junto aos demais recursos de observabilidade sem remover containers ou dados gerenciados pelo Coolify
