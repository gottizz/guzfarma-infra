# Contrato del módulo. Reemplazar cada `null` por el valor real.

output "orders_queue_url" {
  description = "URL de la cola de pedidos (la usa la API)."
  value       = null # TODO: aws_sqs_queue.orders.url
}

output "orders_queue_arn" {
  description = "ARN de la cola de pedidos."
  value       = null # TODO: aws_sqs_queue.orders.arn
}

output "dlq_name" {
  description = "Nombre de la DLQ (para la alarma de CloudWatch)."
  value       = null # TODO: aws_sqs_queue.orders_dlq.name
}

output "alerts_topic_arn" {
  description = "Tópico SNS de alertas (stock bajo y alarmas técnicas)."
  value       = null # TODO: aws_sns_topic.alerts.arn
}

output "notif_lambda_name" {
  description = "Nombre de la Lambda notif-pedido."
  value       = null # TODO: aws_lambda_function.notif.function_name
}

output "stock_lambda_name" {
  description = "Nombre de la Lambda stock-monitor."
  value       = null # TODO: aws_lambda_function.stock.function_name
}
