"""Lambda notif-pedido (paso 7 del diagrama).

Lee pedidos confirmados desde la cola SQS y envía el correo de confirmación
al cliente con SES. Si un mensaje falla, se reporta como fallido para que SQS
lo reintente y, tras 3 intentos, lo mande a la DLQ.

Responsable: Integrante 3. Estado: esqueleto.
"""
import json
import os

import boto3

ses = boto3.client("sesv2")
SENDER = os.environ.get("SENDER_EMAIL", "")


def lambda_handler(event, context):
    failures = []
    for record in event.get("Records", []):
        try:
            pedido = json.loads(record["body"])
            # TODO: validar campos (id, email, items, total) y armar el cuerpo del correo
            ses.send_email(
                FromEmailAddress=SENDER,
                Destination={"ToAddresses": [pedido["email"]]},
                Content={
                    "Simple": {
                        "Subject": {"Data": f"Guzfarma - Pedido {pedido['id']} confirmado"},
                        "Body": {"Text": {"Data": "Tu pedido está listo para recoger en tienda."}},
                    }
                },
            )
        except Exception as exc:  # noqa: BLE001
            print(f"Error procesando {record.get('messageId')}: {exc}")
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
