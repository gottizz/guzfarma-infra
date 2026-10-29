# Módulo `compute`

**Responsable:** Integrante 4

**Qué crea:** Repositorios ECR, ALB único con reglas por ruta, ECS Fargate con nginx y API, y Service Auto Scaling.

**Depende de:** network, security, database, events

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
