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

data "archive_file" "notif" {
  type        = "zip"
  source_dir  = "${var.lambdas_source_dir}/notif_pedido"
  output_path = "${path.module}/.build/notif_pedido.zip"
}

resource "aws_cloudwatch_log_group" "notif" {
  name              = "/aws/lambda/${local.notif_name}"
  retention_in_days = 90
  tags              = local.tags
}

resource "aws_lambda_function" "notif" {
  function_name = local.notif_name
  description   = "Envía por SES la confirmación de cada pedido de la cola SQS."
  role          = local.notif_role_arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = local.notif_timeout
  memory_size   = 128

  filename         = data.archive_file.notif.output_path
  source_code_hash = data.archive_file.notif.output_base64sha256

  environment {
    variables = {
      SENDER_EMAIL = var.ses_sender_email
    }
  }

  tags = local.tags

  depends_on = [
    aws_cloudwatch_log_group.notif,
    aws_iam_role_policy_attachment.notif_logs,
    aws_iam_role_policy.notif,
  ]
}

resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.notif.arn
  batch_size       = 10

  # Solo se reintentan los mensajes que fallaron, no todo el lote.
  function_response_types = ["ReportBatchItemFailures"]

  tags = local.tags
}

# Llega un correo de AWS al remitente: hay que abrir el enlace para verificarlo.
resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.ses_sender_email
  tags           = local.tags
}

# --- Alertas de stock (paso 8) -----------------------------------------------

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = local.tags
}

# Llega un correo al administrador: hay que confirmar la suscripción.
resource "aws_sns_topic_subscription" "admin" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

# stock-monitor usa `oracledb` (modo thin), que no viene en Lambda. Se instala
# junto al handler, con ruedas para Linux x86_64 / Python 3.12, sin importar el
# sistema operativo desde el que se ejecute Terraform. Requiere `pip` en el PATH.
resource "terraform_data" "stock_deps" {
  triggers_replace = [
    filesha256("${var.lambdas_source_dir}/stock_monitor/requirements.txt"),
  ]

  provisioner "local-exec" {
    working_dir = "${var.lambdas_source_dir}/stock_monitor"
    command     = "pip install --quiet --upgrade --requirement requirements.txt --target vendor --platform manylinux2014_x86_64 --platform manylinux_2_28_x86_64 --implementation cp --python-version 3.12 --only-binary=:all:"
  }
}

data "archive_file" "stock" {
  type        = "zip"
  source_dir  = "${var.lambdas_source_dir}/stock_monitor"
  output_path = "${path.module}/.build/stock_monitor.zip"
  excludes    = ["requirements.txt"]

  depends_on = [terraform_data.stock_deps]
}

resource "aws_cloudwatch_log_group" "stock" {
  name              = "/aws/lambda/${local.stock_name}"
  retention_in_days = 90
  tags              = local.tags
}

resource "aws_lambda_function" "stock" {
  function_name = local.stock_name
  description   = "Consulta en Oracle los productos bajo su stock mínimo y avisa por SNS."
  role          = local.stock_role_arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = local.stock_timeout
  memory_size   = 256

  filename         = data.archive_file.stock.output_path
  source_code_hash = data.archive_file.stock.output_base64sha256

  vpc_config {
    subnet_ids         = var.app_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  environment {
    variables = {
      DB_HOST          = var.db_address
      DB_PORT          = tostring(var.db_port)
      DB_SERVICE       = var.db_name
      DB_SECRET_ARN    = var.db_secret_arn
      ALERTS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  tags = local.tags

  depends_on = [
    aws_cloudwatch_log_group.stock,
    aws_iam_role_policy_attachment.stock_vpc,
    aws_iam_role_policy.stock,
  ]
}

resource "aws_cloudwatch_event_rule" "stock_daily" {
  name                = "${local.name}-stock-daily"
  description         = "Dispara stock-monitor una vez al día."
  schedule_expression = var.stock_check_schedule
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "stock" {
  rule = aws_cloudwatch_event_rule.stock_daily.name
  arn  = aws_lambda_function.stock.arn

  retry_policy {
    maximum_retry_attempts = 2
  }
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stock.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stock_daily.arn
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

locals {
  stock_role_arn = coalesce(var.existing_role_arn, one(aws_iam_role.stock[*].arn))
}

# stock-monitor: corre en la VPC, lee el secreto de Oracle y publica en SNS
resource "aws_iam_role" "stock" {
  count = local.create_roles ? 1 : 0

  name               = "${local.stock_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "stock_vpc" {
  count = local.create_roles ? 1 : 0

  role       = aws_iam_role.stock[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "stock" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "stock" {
  count = local.create_roles ? 1 : 0

  name   = "stock-monitor"
  role   = aws_iam_role.stock[0].id
  policy = data.aws_iam_policy_document.stock.json
}
