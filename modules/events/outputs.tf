# Contrato del módulo.

output "orders_queue_url" {
  description = "URL de la cola de pedidos (la usa la API)."
  value       = aws_sqs_queue.orders.url
}

output "orders_queue_arn" {
  description = "ARN de la cola de pedidos."
  value       = aws_sqs_queue.orders.arn
}

output "dlq_name" {
  description = "Nombre de la DLQ (para la alarma de CloudWatch)."
  value       = aws_sqs_queue.orders_dlq.name
}

output "alerts_topic_arn" {
  description = "Tópico SNS de alertas (stock bajo y alarmas técnicas)."
  value       = aws_sns_topic.alerts.arn
}

output "notif_lambda_name" {
  description = "Nombre de la Lambda notif-pedido."
  value       = aws_lambda_function.notif.function_name
}

output "stock_lambda_name" {
  description = "Nombre de la Lambda stock-monitor."
  value       = aws_lambda_function.stock.function_name
}
