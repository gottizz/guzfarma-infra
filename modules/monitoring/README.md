# Módulo `monitoring`

**Responsable:** Integrante 1

**Qué crea:** Alarmas de CloudWatch (latencia, 5xx, CPU, almacenamiento, DLQ, errores de Lambda) hacia SNS.

**Depende de:** compute, database, events

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
