# Módulo `edge`

**Responsable:** Integrante 5

**Qué crea:** Cognito, API Gateway HTTP con VPC Link y authorizer JWT, CloudFront, WAF (CloudFront y ALB) y Route 53 opcional.

**Depende de:** network, security, compute

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
