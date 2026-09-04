# Integração com Espresso Infra

Voltar para o [README](../README.md).

Este repositório pressupõe que o [Espresso Infra](https://github.com/evellyncosta/espresso-infra) já disponibilizou acesso SSH à VPS, Docker Engine, Docker Compose e Coolify. Ele não instala nem altera esses componentes.

O collector PostgreSQL também pressupõe que o PostgreSQL da aplicação já esteja em execução pelo Coolify e seja acessível na rede Docker `coolify` (ou na rede configurada). A rede `signoz-network` só passa a existir depois da instalação SigNoz.

| Responsável | Escopo |
| --- | --- |
| Espresso Infra | VPS, SSH, Docker, Compose, UFW base e Coolify. |
| Espresso Observability | SigNoz, Foundry, regras UFW específicas do SigNoz e collector PostgreSQL. |
| Coolify | Aplicação, PostgreSQL, Redis/Valkey, domínio, deploy e dados da aplicação. |
