"""Lambda notif-pedido (paso 7 del diagrama).

Lee pedidos confirmados desde la cola SQS y envía el correo de confirmación
al cliente con SES. Si un mensaje falla, se reporta como fallido para que SQS
lo reintente y, tras 3 intentos, lo mande a la DLQ.

Formato esperado del mensaje (JSON en el body):
    {
      "id": "P-1001",
      "email": "cliente@correo.com",
      "items": [{"nombre": "Paracetamol 500 mg", "cantidad": 2, "precio": 3.5}],
      "total": 7.0
    }

Responsable: Integrante 3.
"""
import json
import os
import re

import boto3

ses = boto3.client("sesv2")
SENDER = os.environ.get("SENDER_EMAIL", "")

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class PedidoInvalido(ValueError):
    """El mensaje no cumple el formato esperado; no tiene sentido reintentarlo igual."""


def _es_numero(valor):
    return isinstance(valor, (int, float)) and not isinstance(valor, bool)


def validar_pedido(pedido):
    """Valida los campos id, email, items y total. Devuelve el pedido normalizado."""
    if not isinstance(pedido, dict):
        raise PedidoInvalido("el mensaje no es un objeto JSON")

    pedido_id = pedido.get("id")
    if pedido_id is None or not str(pedido_id).strip():
        raise PedidoInvalido("falta el campo 'id'")

    email = pedido.get("email")
    if not isinstance(email, str) or not EMAIL_RE.match(email.strip()):
        raise PedidoInvalido("'email' ausente o con formato inválido")

    items = pedido.get("items")
    if not isinstance(items, list) or not items:
        raise PedidoInvalido("'items' debe ser una lista con al menos un producto")

    normalizados = []
    for posicion, item in enumerate(items, start=1):
        if not isinstance(item, dict):
            raise PedidoInvalido(f"el item {posicion} no es un objeto")
        nombre = item.get("nombre") or item.get("name")
        if not isinstance(nombre, str) or not nombre.strip():
            raise PedidoInvalido(f"el item {posicion} no tiene 'nombre'")
        cantidad = item.get("cantidad", item.get("quantity"))
        if not _es_numero(cantidad) or cantidad <= 0:
            raise PedidoInvalido(f"el item {posicion} tiene 'cantidad' inválida")
        precio = item.get("precio", item.get("price"))
        if precio is not None and (not _es_numero(precio) or precio < 0):
            raise PedidoInvalido(f"el item {posicion} tiene 'precio' inválido")
        normalizados.append({"nombre": nombre.strip(), "cantidad": cantidad, "precio": precio})

    total = pedido.get("total")
    if not _es_numero(total) or total < 0:
        raise PedidoInvalido("'total' ausente o inválido")

    return {
        "id": str(pedido_id).strip(),
        "email": email.strip(),
        "items": normalizados,
        "total": total,
    }


def armar_cuerpo(pedido):
    """Arma el texto del correo de confirmación."""
    lineas = [
        "Hola,",
        "",
        f"Tu pedido {pedido['id']} fue confirmado y está listo para recoger en tienda.",
        "",
        "Detalle:",
    ]
    for item in pedido["items"]:
        linea = f"  - {item['nombre']} x{item['cantidad']}"
        if item["precio"] is not None:
            linea += f"  (S/ {item['precio']:.2f} c/u)"
        lineas.append(linea)
    lineas += ["", f"Total: S/ {pedido['total']:.2f}", "", "Gracias por tu compra.", "Guzfarma"]
    return "\n".join(lineas)


def enviar_confirmacion(pedido):
    ses.send_email(
        FromEmailAddress=SENDER,
        Destination={"ToAddresses": [pedido["email"]]},
        Content={
            "Simple": {
                "Subject": {"Data": f"Guzfarma - Pedido {pedido['id']} confirmado", "Charset": "UTF-8"},
                "Body": {"Text": {"Data": armar_cuerpo(pedido), "Charset": "UTF-8"}},
            }
        },
    )


def lambda_handler(event, context):
    failures = []
    for record in event.get("Records", []):
        try:
            pedido = validar_pedido(json.loads(record["body"]))
            enviar_confirmacion(pedido)
        except Exception as exc:  # noqa: BLE001
            print(f"Error procesando {record.get('messageId')}: {exc}")
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
