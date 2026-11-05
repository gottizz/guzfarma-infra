# =============================================================================
# Módulo: monitoring  ·  Responsable: Integrante 1
# Diagrama: CloudWatch (logs + alarmas) -> SNS -> Administrador (paso 10)
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "monitoring" })

  # Todas las alarmas avisan al administrador por el tópico SNS de alertas,
  # tanto al dispararse como al volver a la normalidad.
  actions = [var.alerts_topic_arn]

  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_api_arn_suffix
  }

  # FreeStorageSpace se mide en bytes: 20 % del almacenamiento asignado.
  rds_free_storage_threshold_bytes = var.rds_allocated_storage_gb * 0.2 * 1024 * 1024 * 1024
}

# --- API (ALB) -----------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "api_latency_p95" {
  alarm_name          = "${local.name}-api-latencia-p95"
  alarm_description   = "Latencia p95 de la API mayor a ${var.latency_p95_threshold_seconds} s durante 5 min (RNF-07 / RNF-12)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.alb_dimensions
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.latency_p95_threshold_seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_rate" {
  alarm_name          = "${local.name}-api-errores-5xx"
  alarm_description   = "Más del ${var.error_5xx_threshold_percent} % de respuestas 5xx de la API en 5 min (RNF-18)."
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.error_5xx_threshold_percent
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags

  metric_query {
    id          = "tasa_5xx"
    expression  = "IF(solicitudes > 0, errores / solicitudes * 100, 0)"
    label       = "Errores 5xx (%)"
    return_data = true
  }

  metric_query {
    id = "errores"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = local.alb_dimensions
      stat        = "Sum"
      period      = 300
    }
  }

  metric_query {
    id = "solicitudes"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = local.alb_dimensions
      stat        = "Sum"
      period      = 300
    }
  }
}

# --- ECS -----------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${local.name}-ecs-cpu"
  alarm_description   = "CPU promedio del servicio ECS mayor a ${var.ecs_cpu_threshold} % durante 5 min (RNF-18)."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.ecs_cpu_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags
}

# --- RDS -----------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-cpu"
  alarm_description   = "CPU de RDS mayor a ${var.rds_cpu_threshold} % durante 10 min (RNF-12)."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.rds_cpu_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name}-rds-espacio-libre"
  alarm_description   = "Espacio libre de RDS por debajo del 20 % de ${var.rds_allocated_storage_gb} GB."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = local.rds_free_storage_threshold_bytes
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags
}

# --- Eventos -------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.name}-dlq-pedidos"
  alarm_description   = "Hay pedidos en la DLQ: la notificación falló tras los reintentos (RNF-05)."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.dlq_name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "stock_lambda_errors" {
  alarm_name          = "${local.name}-stock-monitor-errores"
  alarm_description   = "La Lambda stock-monitor terminó con error."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = var.stock_lambda_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = local.tags
}

# --- Tablero -------------------------------------------------------------------

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name

  widgets = [
    {
      title   = "API · latencia p95 (s)"
      metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_api_arn_suffix, { stat = "p95" }]]
    },
    {
      title = "API · solicitudes y errores 5xx"
      metrics = [
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_api_arn_suffix, { stat = "Sum" }],
        ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_api_arn_suffix, { stat = "Sum" }],
      ]
    },
    {
      title   = "ECS · CPU (%)"
      metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]]
    },
    {
      title   = "RDS · CPU (%)"
      metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id]]
    },
    {
      title   = "RDS · espacio libre (bytes)"
      metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_instance_id, { stat = "Minimum" }]]
    },
    {
      title = "Eventos · DLQ y errores de stock-monitor"
      metrics = [
        ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name, { stat = "Maximum" }],
        ["AWS/Lambda", "Errors", "FunctionName", var.stock_lambda_name, { stat = "Sum" }],
      ]
    },
  ]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${local.name}-operacion"

  dashboard_body = jsonencode({
    widgets = [
      for i, w in local.widgets : {
        type   = "metric"
        x      = (i % 2) * 12
        y      = floor(i / 2) * 6
        width  = 12
        height = 6
        properties = {
          title   = w.title
          region  = local.region
          metrics = w.metrics
          period  = 300
          view    = "timeSeries"
        }
      }
    ]
  })
}
