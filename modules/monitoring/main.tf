# =============================================================================
# Módulo: monitoring  ·  Responsable: Integrante 1
# Diagrama: CloudWatch (logs + alarmas) -> SNS -> Administrador (paso 10)
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, { Module = "monitoring" })
}

# TODO (Integrante 1) - todas las alarmas con alarm_actions = [var.alerts_topic_arn]
#
# [ ] alarma latencia API        AWS/ApplicationELB TargetResponseTime, extended_statistic = "p95",
#                                > var.latency_p95_threshold_seconds durante 5 min (dimensiones LoadBalancer + TargetGroup)
# [ ] alarma errores 5xx         metric math: HTTPCode_Target_5XX_Count / RequestCount * 100 > var.error_5xx_threshold_percent
# [ ] alarma CPU ECS             AWS/ECS CPUUtilization > var.ecs_cpu_threshold (dimensiones ClusterName + ServiceName)
# [ ] alarma CPU RDS             AWS/RDS CPUUtilization > var.rds_cpu_threshold durante 10 min
# [ ] alarma espacio RDS         AWS/RDS FreeStorageSpace < 20% del almacenamiento asignado
# [ ] alarma DLQ                 AWS/SQS ApproximateNumberOfMessagesVisible > 0 en var.dlq_name (RNF-05)
# [ ] alarma stock-monitor       AWS/Lambda Errors > 0 en var.stock_lambda_name
# [ ] aws_cloudwatch_dashboard   un tablero con las métricas de arriba (opcional para este avance)
#
# Criterio de terminado: plan muestra las alarmas y, al forzar un mensaje en la DLQ,
# llega el correo de alarma al administrador.
