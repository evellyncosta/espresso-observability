# Operação

Voltar para o [README](../README.md).

Crie `.env` a partir de `.env.example`. As únicas variáveis obrigatórias são `SERVER_HOST`, `SERVER_USER` e `SSH_KEY_PATH`.

| Comando | Efeito |
| --- | --- |
| `task preflight` | Valida ambiente local e SSH. |
| `task setup` | Configura firewall específico e instala SigNoz. |
| `task install:postgres-collector` | Instala ou reconcilia o collector. |
| `task install:application-otel-collector` | Instala ou reconcilia o collector OTLP de métricas e traces da aplicação. |
| `task status` | Exibe recursos e pré-requisitos sem segredos. |
| `task destroy` | Remove recursos de observabilidade. |

`task destroy` é idempotente. Ele só remove regras UFW com comentário `SigNoz observability`; regras de SSH, HTTP, HTTPS e Coolify não são seu escopo. Por padrão, preserva a role de monitoramento PostgreSQL.

O collector OTLP da aplicação atende apenas ao ambiente `production`. Depois de instalá-lo, configure o deploy da aplicação no Coolify para exportar métricas e traces OTLP ao hostname interno `espresso-application-otel-collector`, usando a porta `4317` para gRPC ou `4318` para HTTP/protobuf. Essa configuração pertence à aplicação e não é alterada por este repositório.
