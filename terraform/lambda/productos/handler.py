"""Lambda "productos" del laboratorio 09.

GET /salud     -> pública, confirma que la API responde.
GET /productos -> protegida por Cognito, devuelve un catálogo de ejemplo.
"""
import json
import os

PRODUCTOS = [
    {"codigo": "P001", "nombre": "Paracetamol 500 mg", "stock": 120},
    {"codigo": "P002", "nombre": "Ibuprofeno 400 mg", "stock": 85},
    {"codigo": "P003", "nombre": "Alcohol en gel 250 ml", "stock": 40},
]


def lambda_handler(event, context):
    ruta = event.get("rawPath", "/")
    if ruta == "/salud":
        cuerpo = {"estado": "ok", "entorno": os.environ.get("ENVIRONMENT", "dev")}
    else:
        cuerpo = {"productos": PRODUCTOS}
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(cuerpo, ensure_ascii=False),
    }
