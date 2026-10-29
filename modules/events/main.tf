# =============================================================================
# Módulo: events  ·  Responsable: Integrante 3
# Diagrama: SQS pedidos + DLQ -> Lambda notif-pedido -> SES (paso 7)
#           EventBridge (cron diario) -> Lambda stock-monitor -> SNS (paso 8)
# =============================================================================

locals {
  name = lower(replace("${var.project}-${var.environment}", "_", "-"))
  tags = merge(var.tags, { Module = "events" })

  notif_name = "${local.name}-notif-pedido"
  stock_name = "${local.name}-stock-monitor"

  notif_timeout = 30
  stock_timeout = 60

  create_roles = var.existing_role_arn == null
}

# --- Pedidos (paso 7) --------------------------------------------------------

resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${local.name}-orders-dlq"
  message_retention_seconds = 1209600 # 14 días
  kms_master_key_id         = var.kms_key_arn
  tags                      = local.tags
}

resource "aws_sqs_queue" "orders" {
  name = "${local.name}-orders"

  # Regla de AWS: visibility timeout >= 6 x timeout de la Lambda que consume la cola.
  visibility_timeout_seconds = 6 * local.notif_timeout
  kms_master_key_id          = var.kms_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = local.tags
}
