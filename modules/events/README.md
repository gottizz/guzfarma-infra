# Módulo `events`

**Responsable:** Integrante 3

**Qué crea:** Cola SQS de pedidos con DLQ, Lambda notif-pedido + SES, EventBridge diario + Lambda stock-monitor + SNS.

**Depende de:** network, security, database

## Cómo trabajar

1. La lista de recursos pendientes está en `main.tf` (líneas `[ ]`). Márcalas con `[x]` al terminarlas.
2. Al crear cada recurso, reemplaza el `null` correspondiente en `outputs.tf`.
3. No cambies nombres de variables ni de outputs sin avisar al grupo.
4. Antes de abrir el Pull Request:

```bash
terraform fmt -recursive
cd ../../envs/dev
terraform init -backend=false
terraform validate
```
