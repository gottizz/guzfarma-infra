# Módulo `security`

**Responsable:** Integrante 2

**Qué crea:** Security Groups, llave KMS, secreto de la pasarela de pago, Parameter Store, Interface Endpoints y S3 Gateway Endpoint.

**Depende de:** network

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
