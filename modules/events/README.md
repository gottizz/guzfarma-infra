# Módulo `events`

**Responsable:** Integrante 3

**Qué crea:** Cola SQS de pedidos con DLQ, Lambda notif-pedido + SES, EventBridge diario + Lambda stock-monitor + SNS.

**Depende de:** network, security, database

## Recursos

- **Pedidos (paso 7):** `orders_dlq` (14 días, KMS) y `orders` con `redrive_policy`; `visibility_timeout_seconds` = 6 x timeout de la Lambda. La Lambda `notif-pedido` (python3.12, sin VPC) consume la cola con `aws_lambda_event_source_mapping` (lote de 10, `ReportBatchItemFailures`) y envía el correo con SES. Un pedido que falla `max_receive_count` veces termina en la DLQ.
- **Alertas (paso 8):** tópico SNS `alerts` (KMS) con suscripción por correo al administrador. La Lambda `stock-monitor` (en la VPC, subredes app y SG-lambda) la dispara una regla diaria de EventBridge (`stock_check_schedule`, con 2 reintentos).
- **Roles y logs:** los roles IAM de las dos Lambda se crean solo si `existing_role_arn == null`; en AWS Academy se pasa el ARN de LabRole. Cada Lambda tiene su log group con retención de 90 días.

## Outputs

`orders_queue_url`, `orders_queue_arn`, `dlq_name`, `alerts_topic_arn`, `notif_lambda_name`, `stock_lambda_name`.

## Código de las Lambda (`lambdas/`)

- `notif_pedido/handler.py`: valida `id`, `email`, `items` y `total`; arma el correo y lo envía. Los mensajes inválidos se devuelven en `batchItemFailures`.
- `stock_monitor/handler.py`: lee el secreto de Oracle, se conecta con `oracledb` en modo thin y consulta `productos` con `stock < stock_minimo`; si hay resultados publica en SNS.

`oracledb` lo instala Terraform (`terraform_data.stock_deps`) en `lambdas/stock_monitor/vendor/` con ruedas para Linux x86_64 y Python 3.12. Por eso, para hacer `terraform apply`, necesitas `pip` en el PATH. La carpeta `vendor/` está en `.gitignore`.

## Para probar después del apply

1. Confirma los dos correos que llegan de AWS: la verificación del remitente de SES y la suscripción al tópico SNS.
2. En SES sandbox, el destinatario del pedido también debe estar verificado.
3. Envía un mensaje a la cola `orders` (formato en el docstring de `notif_pedido/handler.py`): debe llegar como correo, o terminar en la DLQ si falla.
4. Para probar `stock-monitor`, invócala a mano desde la consola de Lambda. Necesita llegar a Secrets Manager y SNS desde la VPC (endpoints del módulo security o NAT).

## Antes de abrir el Pull Request

```bash
terraform fmt -recursive
cd envs/dev
terraform init -backend=false
terraform validate
```
