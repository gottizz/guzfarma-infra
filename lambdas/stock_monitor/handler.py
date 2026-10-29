"""Lambda stock-monitor (paso 8 del diagrama).

EventBridge la ejecuta una vez al día. Consulta en Oracle los productos con
stock por debajo de su mínimo y publica la lista en el tópico SNS de alertas,
al que está suscrito el administrador.

Responsable: Integrante 3. Estado: esqueleto.
Nota: para conectarse a Oracle se necesita el paquete `oracledb` (modo thin),
que se empaqueta junto al handler o como Lambda Layer.
"""
import json
import os

import boto3

sns = boto3.client("sns")
secrets = boto3.client("secretsmanager")


def obtener_productos_bajo_minimo():
    # TODO: leer credenciales de DB_SECRET_ARN y consultar:
    #   SELECT codigo, nombre, stock, stock_minimo FROM productos WHERE stock < stock_minimo
    return []


def lambda_handler(event, context):
    productos = obtener_productos_bajo_minimo()
    if productos:
        sns.publish(
            TopicArn=os.environ["ALERTS_TOPIC_ARN"],
            Subject="Guzfarma - Productos con stock bajo",
            Message=json.dumps(productos, ensure_ascii=False, indent=2),
        )
    return {"productos_bajo_minimo": len(productos)}
