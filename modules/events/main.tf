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

# --- Permisos ----------------------------------------------------------------
# Los roles solo se crean si no se entrega var.existing_role_arn
# (AWS Academy no permite crear roles: se usa LabRole).

locals {
  notif_role_arn = coalesce(var.existing_role_arn, one(aws_iam_role.notif[*].arn))
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# notif-pedido: lee la cola, envía correos y escribe logs
resource "aws_iam_role" "notif" {
  count = local.create_roles ? 1 : 0

  name               = "${local.notif_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "notif_logs" {
  count = local.create_roles ? 1 : 0

  role       = aws_iam_role.notif[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "notif" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.orders.arn]
  }

  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "notif" {
  count = local.create_roles ? 1 : 0

  name   = "notif-pedido"
  role   = aws_iam_role.notif[0].id
  policy = data.aws_iam_policy_document.notif.json
}
