# Módulo `compute`

**Responsable:** Integrante 4

**Qué crea:** Repositorios ECR, ALB único con reglas por ruta, ECS Fargate con nginx y API, y Service Auto Scaling.

**Depende de:** network, security, database, events

## Recursos

| Bloque | Recursos |
|---|---|
| Imágenes | `aws_ecr_repository.api` y `.web` (scan on push, cifrado KMS), `aws_ecr_lifecycle_policy` (últimas 10) |
| Balanceador | `aws_lb.this` (público, 2 AZ), TG `web` :80 y `api` :8080 (`target_type = "ip"`), listener 80, listener 443 (solo con `certificate_arn`), regla `/api/*` → TG-api |
| ECS | log groups `/ecs/guzfarma-dev/{api,web}`, roles de ejecución y de tarea (o `LabRole`), cluster con Container Insights, task definition con 2 contenedores, servicio Fargate con circuit breaker |
| Auto Scaling | target (min/max), política por CPU, 4 acciones programadas |

## Imágenes de prueba

Mientras no exista la aplicación real, el módulo funciona con imágenes públicas:

- `web`: `public.ecr.aws/nginx/nginx:stable` (valor por defecto de `frontend_image`). Se le crea un archivo `/health` al arrancar para pasar el health check.
- `api`: si `api_image = ""`, se usa `busybox` con `httpd` en el puerto 8080, que responde `/health` y `/api/`.

Con eso, tras el `apply`, `http://<alb_dns_name>` muestra la página de bienvenida de nginx
y `http://<alb_dns_name>/api/` responde `{"status":"ok"}`.

Cuando exista la imagen real (la de nginx debe responder `/health` en :80 y la API `/health` en :8080):

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <cuenta>.dkr.ecr.us-east-1.amazonaws.com
docker build -t <ecr_api_url>:v1 ./api && docker push <ecr_api_url>:v1
```

y en `envs/dev` se pasa `api_image = "<ecr_api_url>:v1"` / `frontend_image = "<ecr_web_url>:v1"`.

## Auto Scaling programado (RNF-09)

Las expresiones cron de Application Auto Scaling están en **UTC** (Lima = UTC-5):

| Acción | Hora Lima | Cron (UTC) | Mínimo |
|---|---|---|---|
| Pico de fin de semana | viernes 18:00 | `cron(0 23 ? * FRI *)` | `peak_min_tasks` |
| Vuelta a lo normal | lunes 08:00 | `cron(0 13 ? * MON *)` | `min_tasks` |
| Pico de fin de mes | día 24, 00:00 | `cron(0 5 24 * ? *)` | `peak_min_tasks` |
| Fin del pico de fin de mes | día 1, 00:00 | `cron(0 5 1 * ? *)` | `min_tasks` |

Limitación conocida: AWS no permite combinar día del mes y día de la semana en la misma expresión,
así que si un lunes cae entre el 24 y fin de mes, esa acción baja el mínimo a lo normal
(la política por CPU sigue escalando si hace falta).

## Antes del `apply`

- El secreto de la pasarela de pago (`payment_secret_arn`) **debe tener un valor** cargado en la consola;
  si está vacío, las tareas no arrancan (`ResourceInitializationError`) y el circuit breaker hace rollback.
- En AWS Academy: `lab_role_arn` en `terraform.tfvars` (se usa `LabRole` como rol de ejecución y de tarea).

## Cómo trabajar

1. La lista de recursos está en `main.tf` (líneas `[x]`).
2. No cambies nombres de variables ni de outputs sin avisar al grupo.
3. Antes de abrir el Pull Request:

```bash
terraform fmt -recursive
cd ../../envs/dev
terraform init -backend=false
terraform validate
```