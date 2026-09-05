## 1. Dashboard versionado

- [x] 1.1 Corrigir `dashboards/operation.json` para que os painéis de INSERT, UPDATE, DELETE e HOT update usem agregação temporal `increase` e agrupem `postgresql.table.name` com `fieldContext: resource`; verificar que as quatro operações aparecem quando `All` está selecionado.

## 2. Verificação

- [x] 2.1 Validar `dashboards/operation.json` com `jq empty dashboards/operation.json` e verificar que todos os painéis usam `increase` e o contexto `resource`, sem incluir painéis fora do escopo de operações DML.
