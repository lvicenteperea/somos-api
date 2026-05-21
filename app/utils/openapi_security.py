"""
Utilidades para enriquecer el esquema OpenAPI de sub-apps con esquemas de seguridad.
"""

from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi


def add_basic_auth_openapi(app: FastAPI, title: str, version: str = "1.0") -> None:
    """
    Inyecta el esquema de seguridad HTTP Basic Auth en el openapi() de una sub-app
    y lo aplica a todas sus operaciones.

    Uso:
        add_basic_auth_openapi(elparking_app, title="ElParking API")
    """

    def _custom_openapi():
        if app.openapi_schema:
            return app.openapi_schema
        schema = get_openapi(
            title=title,
            version=version,
            routes=app.routes,
        )
        schema.setdefault("components", {}).setdefault("securitySchemes", {})["basicAuth"] = {
            "type": "http",
            "scheme": "basic",
            "description": "Autenticación HTTP Basic Auth (usuario y contraseña)",
        }
        for path in schema.get("paths", {}).values():
            for operation in path.values():
                if isinstance(operation, dict):
                    operation["security"] = [{"basicAuth": []}]
        app.openapi_schema = schema
        return schema

    app.openapi = _custom_openapi
