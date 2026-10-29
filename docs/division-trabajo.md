# División del trabajo · Avance de Terraform

El repositorio ya trae la estructura completa y el **contrato** de cada módulo:
qué variables recibe (`variables.tf`) y qué devuelve (`outputs.tf`). Gracias a eso,
los 5 pueden trabajar al mismo tiempo sin esperar a nadie: cada uno solo escribe
los recursos dentro de su `main.tf` y reemplaza los `null` de sus outputs.

> Regla de oro: **no cambiar los nombres de variables ni de outputs** de un módulo
> sin avisar al grupo, porque otros módulos dependen de ellos.

## Reparto

| Integrante | Rol | Módulos | Rama | Servicios del diagrama |
|---|---|---|---|---|
| **1** | Red e integración (líder técnico) | `bootstrap/`, `modules/network`, `modules/monitoring`, `envs/dev` | `feat/network` | VPC, subredes, IGW, NAT, tablas de rutas, estado remoto, alarmas CloudWatch |
| **2** | Seguridad | `modules/security` | `feat/security` | Security Groups, KMS, Secrets Manager, Parameter Store, Interface Endpoints, S3 Gateway Endpoint |
| **3** | Datos y eventos | `modules/database`, `modules/events`, `lambdas/` | `feat/database` y `feat/events` | RDS Oracle Multi-AZ, S3 RMAN, SQS + DLQ, Lambda notif-pedido y stock-monitor, SES, SNS, EventBridge |
| **4** | Cómputo | `modules/compute` | `feat/compute` | ECR, ALB, target groups, ECS Fargate (nginx + API), Service Auto Scaling |
| **5** | Borde | `modules/edge` | `feat/edge` | Cognito, API Gateway + VPC Link, CloudFront, WAF (CloudFront y ALB), Route 53 |

Escriban sus nombres aquí:

| Integrante | Nombre | Usuario de GitHub |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |

## Qué hace cada uno

Cada `main.tf` tiene una lista `[ ]` con los recursos exactos que faltan, en orden,
y al final un **criterio de terminado**. Resumen:

### Integrante 1 · Red, estado remoto, monitoreo e integración
1. Aplicar `bootstrap/` una sola vez y crear `envs/dev/backend.hcl` con el bucket que devuelve.
2. `modules/network`: VPC, 6 subredes, IGW, NAT (1 o 2), tablas de rutas.
3. `modules/monitoring`: 7 alarmas de CloudWatch hacia el SNS de alertas.
4. Revisar y aprobar los Pull Requests de los demás, y hacer el `apply` final del entorno.

### Integrante 2 · Seguridad
1. Los 6 Security Groups de la tabla "Puertos y Security Groups" del diagrama.
2. Llave KMS con rotación, secreto de la pasarela de pago y parámetros en Parameter Store.
3. Interface Endpoints (con el interruptor `enable_interface_endpoints`) y S3 Gateway Endpoint.

### Integrante 3 · Base de datos y eventos
1. `modules/database`: RDS Oracle SE2 con `manage_master_user_password`, Multi-AZ opcional,
   option group con `S3_INTEGRATION` y bucket S3 para RMAN.
2. `modules/events`: cola de pedidos con DLQ, las 2 Lambda, SES, SNS y la regla diaria de EventBridge.
3. Completar el código de `lambdas/notif_pedido` y `lambdas/stock_monitor`.

### Integrante 4 · Cómputo
1. Repositorios ECR (api y web).
2. Un solo ALB con 2 target groups y la regla `/api/*`.
3. Cluster, task definition con 2 contenedores, servicio y Auto Scaling (por CPU y programado).

### Integrante 5 · Borde
1. Cognito (user pool, cliente, 4 grupos).
2. API Gateway HTTP con VPC Link, authorizer JWT y throttling.
3. WAF de CloudFront, distribución CloudFront con 2 orígenes, WAF regional asociado al ALB.
4. Registro en Route 53 solo si consiguen dominio propio.

## Orden de integración

Todos programan en paralelo, pero los Pull Requests se fusionan en `main` en este orden,
porque cada módulo usa outputs del anterior:

```
bootstrap → network → security → database → events → compute → edge → monitoring
   (1)        (1)        (2)        (3)        (3)       (4)      (5)      (1)
```

Mientras su dependencia no esté fusionada, pueden validar su módulo igual
(`terraform validate` funciona con los outputs en `null`).

## Entregable del avance (sugerido)

- [ ] Repositorio en GitHub con las 5 ramas y sus Pull Requests
- [ ] CI en verde (formato y validación)
- [ ] `terraform plan` del entorno dev completo, sin errores
- [ ] Captura de la consola de AWS con al menos la red, el ALB y ECS creados
- [ ] `terraform destroy` al terminar la demo para no gastar créditos
