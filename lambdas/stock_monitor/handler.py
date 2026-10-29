"""Lambda stock-monitor (paso 8 del diagrama).

EventBridge la ejecuta una vez al día. Consulta en Oracle los productos con
stock por debajo de su mínimo y publica la lista en el tópico SNS de alertas,
al que está suscrito el administrador.

Variables de entorno: DB_HOST, DB_PORT, DB_SERVICE, DB_SECRET_ARN, ALERTS_TOPIC_ARN.

Para conectarse a Oracle se usa `oracledb` en modo thin (sin Oracle Client).
Terraform lo instala en la carpeta `vendor/` junto a este archivo.

Responsable: Integrante 3.
"""
import json
import os
import sys

# Dependencias empaquetadas junto al handler (ver requirements.txt).
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendor"))

import boto3  # noqa: E402

sns = boto3.client("sns")
secrets = boto3.client("secretsmanager")

CONSULTA = "SELECT codigo, nombre, stock, stock_minimo FROM productos WHERE stock < stock_minimo"
MAX_PRODUCTOS_EN_MENSAJE = 200


def leer_credenciales():
    """Lee usuario y contraseña del secreto que RDS administra en Secrets Manager."""
    respuesta = secrets.get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    secreto = json.loads(respuesta["SecretString"])
    return secreto["username"], secreto["password"]


def obtener_productos_bajo_minimo():
    import oracledb  # modo thin: no requiere Oracle Client

    usuario, clave = leer_credenciales()
    dsn = f"{os.environ['DB_HOST']}:{os.environ['DB_PORT']}/{os.environ['DB_SERVICE']}"

    conexion = oracledb.connect(user=usuario, password=clave, dsn=dsn)
    try:
        with conexion.cursor() as cursor:
            cursor.execute(CONSULTA)
            columnas = [c[0].lower() for c in cursor.description]
            return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]
    finally:
        conexion.close()


def armar_mensaje(productos):
    lineas = [f"Hay {len(productos)} producto(s) por debajo de su stock mínimo:", ""]
    for p in productos[:MAX_PRODUCTOS_EN_MENSAJE]:
        lineas.append(f"- [{p['codigo']}] {p['nombre']}: stock {p['stock']} (mínimo {p['stock_minimo']})")
    if len(productos) > MAX_PRODUCTOS_EN_MENSAJE:
        lineas.append(f"... y {len(productos) - MAX_PRODUCTOS_EN_MENSAJE} más.")
    return "\n".join(lineas)


def lambda_handler(event, context):
    productos = obtener_productos_bajo_minimo()
    if productos:
        sns.publish(
            TopicArn=os.environ["ALERTS_TOPIC_ARN"],
            Subject="Guzfarma - Productos con stock bajo",
            Message=armar_mensaje(productos),
        )
    return {"productos_bajo_minimo": len(productos)}
