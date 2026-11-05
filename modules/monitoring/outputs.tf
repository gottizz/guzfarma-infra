# Contrato del módulo.

output "alarm_names" {
  description = "Nombres de las alarmas creadas."
  value = [
    aws_cloudwatch_metric_alarm.api_latency_p95.alarm_name,
    aws_cloudwatch_metric_alarm.api_5xx_rate.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.rds_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.rds_free_storage.alarm_name,
    aws_cloudwatch_metric_alarm.dlq_messages.alarm_name,
    aws_cloudwatch_metric_alarm.stock_lambda_errors.alarm_name,
  ]
}
