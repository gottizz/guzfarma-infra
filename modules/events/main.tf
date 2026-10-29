# =============================================================================
# Módulo: events  ·  Responsable: Integrante 3
# Diagrama: SQS pedidos + DLQ -> Lambda notif-pedido -> SES (paso 7)
#           EventBridge (cron diario) -> Lambda stock-monitor -> SNS (paso 8)
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "events" })
}

# TODO (Integrante 3)
#
# --- Pedidos (paso 7) ---
# [ ] aws_sqs_queue.orders_dlq      message_retention_seconds = 1209600 (14 días), kms_master_key_id = var.kms_key_arn
# [ ] aws_sqs_queue.orders          redrive_policy = { deadLetterTargetArn = DLQ, maxReceiveCount = var.max_receive_count }
#                                   visibility_timeout_seconds >= 6 x timeout de la Lambda
# [ ] data "archive_file" notif     source_dir = "${var.lambdas_source_dir}/notif_pedido" (provider hashicorp/archive)
# [ ] aws_lambda_function.notif     runtime python3.12, handler = "handler.lambda_handler"
#                                   environment: SENDER_EMAIL = var.ses_sender_email
#                                   (no necesita VPC: no toca la base, solo SQS y SES)
# [ ] aws_lambda_event_source_mapping.orders   SQS -> notif, batch_size = 10,
#                                              function_response_types = ["ReportBatchItemFailures"]
# [ ] aws_sesv2_email_identity.sender          var.ses_sender_email (llega un correo para verificarlo)
#
# --- Alertas de stock (paso 8) ---
# [ ] aws_sns_topic.alerts                     kms_master_key_id = var.kms_key_arn
# [ ] aws_sns_topic_subscription.admin         protocol = "email", endpoint = var.admin_email (confirmar desde el correo)
# [ ] data "archive_file" stock                source_dir = "${var.lambdas_source_dir}/stock_monitor"
# [ ] aws_lambda_function.stock                vpc_config { subnet_ids = var.app_subnet_ids, security_group_ids = [var.sg_lambda_id] }
#                                              environment: DB_HOST, DB_PORT, DB_SECRET_ARN, ALERTS_TOPIC_ARN
# [ ] aws_cloudwatch_event_rule.stock_daily    schedule_expression = var.stock_check_schedule
# [ ] aws_cloudwatch_event_target.stock        -> Lambda stock, retry_policy { maximum_retry_attempts = 2 }
# [ ] aws_lambda_permission.eventbridge        principal = "events.amazonaws.com"
#
# --- Permisos y logs ---
# [ ] aws_iam_role.notif / .stock   (solo si var.existing_role_arn == null)
#       notif: sqs:ReceiveMessage/DeleteMessage/GetQueueAttributes en la cola, ses:SendEmail, logs
#       stock: AWSLambdaVPCAccessExecutionRole, secretsmanager:GetSecretValue en var.db_secret_arn, sns:Publish, kms:Decrypt
# [ ] aws_cloudwatch_log_group para cada Lambda, retención 90 días
#
# Criterio de terminado: un mensaje de prueba en la cola llega como correo (o termina en la DLQ si falla).
