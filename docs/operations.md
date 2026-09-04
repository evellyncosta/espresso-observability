# Operação

Voltar para o [README](../README.md).

Crie `.env` a partir de `.env.example`. As únicas variáveis obrigatórias são `SERVER_HOST`, `SERVER_USER` e `SSH_KEY_PATH`.

| Comando | Efeito |
| --- | --- |
| `task preflight` | Valida ambiente local e SSH. |
| `task setup` | Configura firewall específico e instala SigNoz. |
| `task install:postgres-collector` | Instala ou reconcilia o collector. |
| `task status` | Exibe recursos e pré-requisitos sem segredos. |
| `task destroy` | Remove recursos de observabilidade. |

`task destroy` é idempotente. Ele só remove regras UFW com comentário `SigNoz observability`; regras de SSH, HTTP, HTTPS e Coolify não são seu escopo. Por padrão, preserva a role de monitoramento PostgreSQL.
