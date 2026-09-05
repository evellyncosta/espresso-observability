## Purpose

Versionar um dashboard SigNoz focado na quantidade de operações DML por tabela do único banco PostgreSQL monitorado.

## ADDED Requirements

### Requirement: Dashboard versionado de operações DML

O repositório SHALL fornecer um dashboard SigNoz chamado `Operation` em formato JSON versionável. O dashboard SHALL exibir séries distintas para INSERT, UPDATE e DELETE da métrica cumulativa `postgresql.operations` e SHALL usar a agregação temporal `increase`, de modo que cada ponto represente a quantidade de operações ocorridas no respectivo intervalo.

#### Scenario: Visualização de operações no período selecionado

- **WHEN** o usuário abre o dashboard e seleciona um intervalo de tempo
- **THEN** o dashboard apresenta a quantidade de INSERT, UPDATE e DELETE ocorridas em cada intervalo

### Requirement: Segmentação por tabela

O dashboard SHALL oferecer uma variável dinâmica baseada no atributo `postgresql.table.name`, com seleção de todas as tabelas disponível. Os painéis de operações SHALL segmentar as séries por tabela usando o contexto de campo `resource` e NÃO SHALL agrupá-las por banco.

#### Scenario: Filtro de uma tabela

- **WHEN** o usuário seleciona uma tabela na variável do dashboard
- **THEN** os painéis mostram somente as séries de operações daquela tabela

#### Scenario: Visualização de todas as tabelas

- **WHEN** o usuário seleciona todas as tabelas
- **THEN** os painéis incluem as séries de todas as tabelas descobertas dinamicamente

### Requirement: Indicador de HOT updates

O dashboard SHALL apresentar um painel complementar de HOT updates, filtrado por `operation = 'hot_upd'`, segmentado por tabela no contexto `resource` e calculado com `increase`.

#### Scenario: Visualização de HOT updates

- **WHEN** há amostras de `postgresql.operations` com `operation = 'hot_upd'`
- **THEN** o painel de HOT updates apresenta a quantidade correspondente para cada tabela em cada intervalo
