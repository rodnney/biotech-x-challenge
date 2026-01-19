# SRE: Runbook e Estratégia de Observabilidade

## Cenário: Falha de Conexão com Banco de Dados
**Incidente:** A aplicação (FastAPI) reporta erros 500 e logs indicam `OperationalError: connection could not be established`.

### 1. Como realizar o Debug (Passo a Passo)
Em ordem de probabilidade e facilidade de verificação:

1.  **Verificar Métricas do RDS (CloudWatch):**
    * A CPU está em 100%?
    * O número de conexões (`DatabaseConnections`) atingiu o limite (`max_connections`)?
2.  **Verificar Conectividade de Rede (VPC/Security Groups):**
    * Houve alteração recente no Terraform?
    * Testar conectividade via **Bastion Host** ou um pod de debug no cluster: `nc -zv db-endpoint 5432`.
3.  **Logs da Aplicação:**
    * O erro é de *timeout* (rede/performance) ou *access denied* (credenciais)?
4.  **Estado do Cluster:**
    * Houve um evento de failover Multi-AZ? (O DNS pode estar propagando).

### 2. Solução e Mitigação Permanente (Post-Mortem)
Se a causa raiz for identificada, aplicamos as seguintes correções para evitar recorrência:

* **Problema:** Credenciais erradas/expiradas.
    * **Solução:** Implementar rotação automática de segredos com AWS Secrets Manager integrado diretamente ao EKS via CSI Driver.
* **Problema:** Esgotamento de Conexões.
    * **Solução:** Implementar **PgBouncer** (Connection Pooling) como sidecar ou serviço intermediário para gerenciar conexões de forma eficiente, evitando sobrecarga no Postgres.
* **Problema:** Alteração acidental de Security Group.
    * **Solução:** Bloquear alterações manuais via IAM e reforçar GitOps (só o Terraform altera infraestrutura).

---

## Estratégia de SLOs e SLIs

Para a plataforma Biotech-X, definimos os seguintes indicadores baseados na satisfação do usuário (cientistas).

### SLI (Service Level Indicator) - O que medimos?
1.  **Disponibilidade de Upload:** Porcentagem de requisições `POST /upload` bem-sucedidas (HTTP 2xx).
2.  **Latência de Filtro:** Tempo de resposta para endpoints de filtragem de dados (`GET /analysis/filter`).
3.  **Taxa de Sucesso de Análise:** Porcentagem de Jobs no AWS Batch que terminam com status `SUCCEEDED`.

### SLO (Service Level Objective) - Nossa meta?
| Categoria | SLO | Justificativa |
| :--- | :--- | :--- |
| **Disponibilidade** | **99.9%** (mensal) | O sistema é crítico para operação diária, permitindo ~43min de indisponibilidade/mês. |
| **Latência (API)** | **95%** das reqs < **500ms** | A interface deve ser responsiva para análise interativa de dados. |
| **Confiabilidade Batch** | **99.0%** de sucesso | Falhas de análise atrasam pesquisas, mas re-tentativas (retries) são aceitáveis. |

### Como acompanhamos?
* **Dashboards:** Grafana conectado ao CloudWatch/Prometheus exibindo os "Error Budgets" restantes.
* **Alertas:** PagerDuty acionado quando a taxa de queima do Error Budget indica que o SLO será violado nas próximas 4 horas.
