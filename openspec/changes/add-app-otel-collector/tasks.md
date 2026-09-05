## 1. Configuração do collector

- [x] 1.1 Adicionar variáveis de ambiente seguras e documentadas para habilitação, diretório, imagem, container, redes, endpoint do SigNoz, nome do serviço e ambiente; verificar que os valores padrão descrevem somente `production` e não contêm segredos.
- [x] 1.2 Criar o script remoto idempotente do collector da aplicação, validando Docker e as redes externas antes da reconciliação; verificar que uma rede ausente encerra o comando com o nome da rede.
- [ ] 1.3 Estender a configuração do OpenTelemetry Collector com pipeline de traces que reutilize o receiver OTLP, atributos de recurso, batch e exporter do SigNoz; verificar que traces deixam de ser rejeitados como `UNIMPLEMENTED`.

## 2. Integração operacional

- [x] 2.1 Expor a instalação ou reconciliação do collector por uma tarefa Taskfile e pelo roteador remoto existente; verificar que o comando chega ao script correto sem imprimir valores sensíveis.
- [x] 2.2 Estender o comando de estado para informar diretório e container do collector da aplicação, além das redes requeridas; verificar que a saída não revela segredos.
- [x] 2.3 Estender a destruição para parar e remover somente a stack e o diretório operacional do collector da aplicação; verificar por inspeção que os recursos da aplicação, Coolify, SigNoz e collector PostgreSQL não são alvos dessa etapa.

## 3. Documentação e validação

- [x] 3.1 Atualizar README e documentos de arquitetura, operação e integração para descrever o fluxo OTLP interno de métricas e traces e o comando de instalação; verificar que não há referência a coleta por polling para esta integração.
- [x] 3.2 Documentar a configuração externa exigida na aplicação do Coolify, incluindo o endpoint OTLP interno do collector e o nome de serviço configurado; verificar que a documentação delimita que essa alteração não é executada por este repositório.
- [x] 3.3 Validar os scripts de shell e a proposta com os comandos de lint/validação disponíveis, incluindo `openspec validate add-app-otel-collector --strict`; verificar que todas as verificações passam.
