## Why

As métricas de operações do PostgreSQL já são coletadas, mas não há um dashboard versionado e focado em INSERT, UPDATE e DELETE. O modelo disponível mistura indicadores gerais do banco e agrega por banco, embora a instalação monitore um único banco.

## What Changes

- Adicionar um dashboard SigNoz versionado chamado `Operation`.
- Exibir a quantidade de INSERT, UPDATE e DELETE da métrica cumulativa `postgresql.operations` em cada intervalo do gráfico, segmentada por tabela.
- Incluir HOT updates como indicador complementar de atualizações.
- Permitir filtrar as séries por tabela com variável dinâmica, sem valores de tabelas fixados no JSON.

## Capabilities

### New Capabilities

- `operation-dashboard`: Dashboard versionado que apresenta as operações DML do único banco PostgreSQL monitorado.

### Modified Capabilities

- Nenhuma.

## Impact

- Novo arquivo `dashboards/operation.json` na implementação.
- Consome métricas `postgresql.operations` já enviadas pelo collector ao SigNoz.
