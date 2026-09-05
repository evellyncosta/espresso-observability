## Context

O repositório já provisiona um collector PostgreSQL como uma stack Compose independente conectada às redes externas `coolify` e `signoz-network`. A aplicação é gerenciada pelo Coolify e opera na rede interna; a telemetria dela será enviada ativamente por OTLP, não coletada por scrape. Consulte `proposal.md` e a especificação desta mudança para a motivação e o contrato de comportamento.

## Goals / Non-Goals

**Goals:**

- Criar um caminho interno, dedicado e idempotente para métricas e traces OTLP da aplicação chegarem ao SigNoz.
- Estabelecer atributos de recurso uniformes para um único ambiente, `production`, e para o serviço configurado.
- Integrar o collector à operação e remoção já existentes sem ampliar o escopo do Coolify.

**Non-Goals:**

- Instrumentar a aplicação, alterar seu Compose, variáveis ou deploy no Coolify.
- Coletar métricas via Prometheus ou por polling da porta HTTP `8082`.
- Adicionar logs, dashboards, alertas, API keys ou suporte a múltiplos ambientes.

## Decisions

### Stack Compose própria com duas redes externas

O collector será uma stack Compose em diretório operacional próprio, com as redes externas `coolify` e `signoz-network`. Ele recebe métricas da aplicação na primeira e usa `signoz-ingester:4317` na segunda.

Essa separação preserva a propriedade do Coolify sobre a aplicação e segue o padrão existente do collector PostgreSQL. Um sidecar no Compose da aplicação foi descartado porque exigiria alterar recursos administrados pelo Coolify; usar o collector PostgreSQL foi descartado para manter lifecycle, configuração e falhas isolados.

### OTLP receiver interno e pipelines de métricas e traces

O collector aceitará OTLP/gRPC e OTLP/HTTP nas portas padrão internas `4317` e `4318`, sem `ports:` publicados no host. A aplicação deverá apontar seu exporter OTLP a um hostname interno estável do collector na rede `coolify`.

Os pipelines de métricas e traces terão o receiver OTLP, processador de recursos, batch e exporter OTLP gRPC para o ingester do SigNoz. Não será definido pipeline de logs nesta mudança. Aceitar os dois protocolos OTLP evita acoplamento ao SDK de linguagem da aplicação; encaminhar traces permite que o SigNoz reconheça o serviço e apresente suas métricas correlacionadas em Services.

### Atributos de recurso inseridos pelo collector

O processador de recursos fará `upsert` de `service.name` a partir de variável de configuração e de `deployment.environment.name=production`. O collector é a fronteira comum de ingestão, portanto é o local que garante a identidade inclusive se a aplicação não a configurar corretamente.

Permitir que a app escolha livremente esses atributos foi descartado porque fragmentaria o serviço no SigNoz. Um valor fixo no código também foi descartado: o nome da aplicação ainda deve ser configurável pelo ambiente operacional.

### Reconciliação, estado e remoção no mesmo conjunto operacional

Serão adicionados script remoto, variáveis de ambiente e tarefa de instalação para o collector. `status` verificará seu diretório/container e `destroy` fará compose down e removerá somente seu diretório após parar a stack.

Reutilizar o script do collector PostgreSQL foi descartado porque as configurações e o escopo de remoção ficariam acoplados.

## Risks / Trade-offs

- [A aplicação não apontar seu SDK OTLP ao hostname interno do collector] → Documentar explicitamente o endpoint interno e validar conectividade por métricas e traces após o deploy da configuração no Coolify.
- [Nomes de serviço inconsistentes ou sobrescritos] → Aplicar `upsert` no collector e expor uma única variável operacional para o nome estável.
- [Collector recebe volume ou cardinalidade excessivos] → Começar apenas com batch e limites de recursos Compose; avaliar controles de cardinalidade quando houver dados reais.
- [A rede `coolify` ou `signoz-network` estiver ausente] → Validar ambas antes de gravar a configuração e falhar de forma explícita.

## Migration Plan

1. Provisionar ou reconciliar o collector após o SigNoz e as redes necessárias existirem.
2. Configurar a aplicação no Coolify com o endpoint OTLP interno do collector e reiniciá-la por seu processo normal de deploy.
3. Gerar tráfego e confirmar traces e métricas sob o `service.name` configurado e ambiente `production` em Services no SigNoz.
4. Em caso de falha, reverter somente a configuração OTLP da aplicação para o valor anterior e remover a stack dedicada; isso não altera o SigNoz, o Coolify nem o collector PostgreSQL.

## Open Questions

- Qual será o valor canônico de `service.name` para a aplicação? A resposta configura o ambiente, mas não muda o desenho nem as tarefas.
