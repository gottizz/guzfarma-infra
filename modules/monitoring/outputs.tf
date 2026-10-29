# Contrato del módulo. Reemplazar cada valor por el real.

output "alarm_names" {
  description = "Nombres de las alarmas creadas."
  value       = [] # TODO: lista con aws_cloudwatch_metric_alarm.*.alarm_name
}
