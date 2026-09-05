## Context

O collector já envia a métrica cumulativa `postgresql.operations` ao SigNoz. `operation` é um atributo da métrica, enquanto `postgresql.database.name` e `postgresql.table.name` são atributos de recurso; há somente um banco monitorado. Veja `proposal.md` para a motivação e a spec para o comportamento requerido.

## Goals / Non-Goals

**Goals:**

- Manter o dashboard como um artefato JSON revisável no repositório.
- Tornar as operações DML comparáveis por tabela no SigNoz.

**Non-Goals:**

- Importar ou sincronizar o dashboard automaticamente com a instância SigNoz.
- Alterar o collector, as métricas emitidas ou outros dashboards PostgreSQL.

## Decisions

- Armazenar o artefato em `dashboards/operation.json`. Um diretório dedicado separa dashboards de scripts de provisionamento e permite acrescentar novos dashboards sem alterar a estrutura.
- Usar uma variável dinâmica `table.name` sobre `postgresql.table.name`, com seleção de todas as tabelas e sem valores fixos. Isso acompanha o schema real do banco e evita referências obsoletas.
- Criar quatro painéis de séries temporais: inserts, updates, deletes e HOT updates. Cada painel filtra um valor de `operation` e agrupa por `postgresql.table.name` com `fieldContext: resource`.
- Calcular `postgresql.operations` com agregação temporal `increase`, pois a métrica tem temporariedade cumulativa e o dashboard deve mostrar a quantidade de operações por intervalo. A agregação espacial será `sum`, para reunir séries quando necessário.
- Omitir locks, conexões, tamanho e estatísticas de índice. Eles são indicadores válidos, mas não pertencem ao objetivo DML do dashboard `Operation`.

## Risks / Trade-offs

- [Uma tabela recém-criada ainda não possui amostras] → A variável a exibirá quando o collector a descobrir no ciclo seguinte.
- [A ausência de operações produz séries vazias ou zeradas] → Preservar o comportamento nativo do SigNoz, sem preencher dados artificialmente.
- [A importação manual pode divergir do arquivo versionado] → Tratar `dashboards/operation.json` como fonte de verdade; automação de sincronização permanece fora de escopo.

## Migration Plan

1. Adicionar o JSON versionado ao repositório.
2. Validar a sintaxe JSON antes de revisão.
3. Importar manualmente o arquivo no SigNoz quando a mudança for entregue.

Para rollback, remover o dashboard importado no SigNoz; nenhuma alteração é feita no collector ou no banco.
