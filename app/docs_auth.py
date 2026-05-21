"""
Módulo para autenticación de la documentación de FastAPI.
Permite que diferentes usuarios vean diferentes endpoints según sus permisos.
"""

import secrets
import hmac
import hashlib
import base64
import os
from typing import Optional, List, Dict, Iterable, Tuple
from fastapi import Request, HTTPException, Form
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse

# Clave secreta para firmar cookies (usar variable de entorno en producción)
DOCS_SECRET_KEY = os.getenv(
    "DOCS_SECRET_KEY", "somos-docs-secret-key-change-in-production"
)

# Determinar si estamos en producción (HTTPS) para cookies seguras
IS_PRODUCTION = os.getenv("ENVIRONMENT", "development").lower() in (
    "production",
    "prod",
    "pre",
    "sad",
)

# Usuarios contemplados de momento.....
DOCS_USERS: Dict[str, Dict] = {
    "admin": {
        "password": "somos-admin.2026!",
        "allowed_tags": ["*"],
        "description": "Administrador - Acceso completo",
    },
    "parkings-admin": {
        "password": "parkings.admin.2026!",
        "allowed_tags": ["parkings_admin"],
        "description": "Usuario Parkings Admin",
    },
    "elparking": {
        "password": "elparking.2026!",
        "allowed_tags": ["elparking"],
        "description": "Usuario ElParking",
    },
    "backoffice": {
        "password": "backoffice.2026!",
        "allowed_tags": ["bo", "corporativa"],
        "description": "Usuario Backoffice",
    },
    "skidata": {
        "password": "skdt@tyu.2026!",
        "allowed_tags": ["skidata"],
        "description": "Usuario Skidata",
    },
    "equinsa":{
        "password": "equinsa.2026!",
        "allowed_tags": ["equinsa"],
        "description": "Usuario Equinsa",
    },
    "parkare":{
        "password": "p4rk4r3@wer.2026!",
        "allowed_tags": ["parkare"],
        "description": "Usuario parkare",
    }
}


def sign_value(value: str) -> str:
    """Firma un valor usando HMAC-SHA256."""
    signature = hmac.new(
        DOCS_SECRET_KEY.encode(), value.encode(), hashlib.sha256
    ).hexdigest()
    return f"{value}.{signature}"


def verify_signed_value(signed_value: str) -> Optional[str]:
    """Verifica y extrae el valor de una cookie firmada."""
    if not signed_value or "." not in signed_value:
        return None

    try:
        value, signature = signed_value.rsplit(".", 1)
        expected_signature = hmac.new(
            DOCS_SECRET_KEY.encode(), value.encode(), hashlib.sha256
        ).hexdigest()

        if hmac.compare_digest(signature, expected_signature):
            return value
        return None
    except Exception:
        return None


def get_current_docs_user(request: Request) -> Optional[str]:
    """Obtiene el usuario actual de la cookie firmada."""
    signed_username = request.cookies.get("docs_session")
    if signed_username:
        username = verify_signed_value(signed_username)
        if username and username in DOCS_USERS:
            return username
    return None
    return None


def get_user_allowed_tags(username: str) -> List[str]:
    """Obtiene los tags permitidos para un usuario."""
    if username in DOCS_USERS:
        return DOCS_USERS[username]["allowed_tags"]
    return []


def _extract_refs_from_object(obj: dict, refs: set) -> None:
    """
    Extrae recursivamente todas las referencias $ref de un objeto.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key == "$ref" and isinstance(value, str):
                # Extraer el nombre del schema de "#/components/schemas/NombreSchema"
                if value.startswith("#/components/schemas/"):
                    schema_name = value.split("/")[-1]
                    refs.add(schema_name)
            else:
                _extract_refs_from_object(value, refs)
    elif isinstance(obj, list):
        for item in obj:
            _extract_refs_from_object(item, refs)


def _get_all_referenced_schemas(schemas: dict, initial_refs: set) -> set:
    """
    Obtiene todos los schemas referenciados, incluyendo referencias anidadas.
    """
    all_refs = set(initial_refs)
    to_process = list(initial_refs)

    while to_process:
        schema_name = to_process.pop()
        if schema_name in schemas:
            nested_refs = set()
            _extract_refs_from_object(schemas[schema_name], nested_refs)
            for ref in nested_refs:
                if ref not in all_refs:
                    all_refs.add(ref)
                    to_process.append(ref)

    return all_refs


def filter_openapi_by_tags(openapi_schema: dict, allowed_tags: List[str]) -> dict:
    """
    Filtra el esquema OpenAPI para mostrar solo las rutas con los tags permitidos
    y solo los schemas utilizados por esas rutas.
    """
    if "*" in allowed_tags:
        return openapi_schema  # Acceso completo

    filtered_schema = openapi_schema.copy()
    filtered_paths = {}

    print(f"allowed_tags: {allowed_tags}")
    for path, methods in openapi_schema.get("paths", {}).items():
        filtered_methods = {}
        for method, details in methods.items():
            endpoint_tags = details.get("tags", [])
            if any(tag in allowed_tags for tag in endpoint_tags):
                filtered_methods[method] = details

        if filtered_methods:
            filtered_paths[path] = filtered_methods

    filtered_schema["paths"] = filtered_paths

    if "tags" in filtered_schema:
        filtered_schema["tags"] = [
            tag
            for tag in filtered_schema["tags"]
            if tag.get("name") in allowed_tags or "*" in allowed_tags
        ]

    # Filtrar schemas: solo los que son usados por las rutas filtradas
    if "components" in openapi_schema and "schemas" in openapi_schema["components"]:
        # Extraer todas las referencias de las rutas filtradas
        used_refs = set()
        _extract_refs_from_object(filtered_paths, used_refs)

        # Obtener también los schemas referenciados de forma anidada
        all_schemas = openapi_schema["components"]["schemas"]
        all_used_schemas = _get_all_referenced_schemas(all_schemas, used_refs)

        # Filtrar los schemas
        filtered_schemas = {
            name: schema
            for name, schema in all_schemas.items()
            if name in all_used_schemas
        }

        # Copiar components y actualizar schemas
        if "components" not in filtered_schema:
            filtered_schema["components"] = {}
        else:
            filtered_schema["components"] = openapi_schema["components"].copy()

        filtered_schema["components"]["schemas"] = filtered_schemas

    return filtered_schema


# TODO: Preguntar a Luis por diseño visual
LOGIN_PAGE_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Somos API Docs - Login</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #ef6a00 0%, #FC993F 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.2);
            width: 100%;
            max-width: 400px;
        }
        h1 {
            text-align: center;
            color: #333;
            margin-bottom: 10px;
        }
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #555;
            font-weight: 500;
        }
        input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e1e1e1;
            border-radius: 6px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
            border-radius: 6px;
            color: white;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        .error {
            background: #fee;
            color: #c00;
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 20px;
            text-align: center;
        }
        .logo {
            text-align: center;
            font-size: 48px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>Somos API Docs</h1>
        <p class="subtitle">Ingresa tus credenciales para acceder a la documentación</p>
        {error_message}
        <form method="post" action="/docs/login">
            <div class="form-group">
                <label for="username">Usuario</label>
                <input type="text" id="username" name="username" required placeholder="Ingresa tu usuario">
            </div>
            <div class="form-group">
                <label for="password">Contraseña</label>
                <input type="password" id="password" name="password" required placeholder="Ingresa tu contraseña">
            </div>
            <button type="submit">Iniciar Sesión</button>
        </form>
    </div>
</body>
</html>
"""


def get_swagger_ui_html(openapi_url: str, title: str, username: str, persist_authorization: bool = False) -> str:
    """Genera el HTML de Swagger UI personalizado."""
    return f"""
<!DOCTYPE html>
<html>
<head>
    <title>{title}</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    <style>
        body {{
            margin: 0;
            padding: 0;
        }}
        .user-bar {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 10px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }}
        .user-bar .user-info {{
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        .user-bar .user-icon {{
            font-size: 20px;
        }}
        .user-bar .logout-btn {{
            background: rgba(255,255,255,0.2);
            color: white;
            border: 1px solid rgba(255,255,255,0.3);
            padding: 8px 16px;
            border-radius: 5px;
            cursor: pointer;
            text-decoration: none;
            font-size: 14px;
            transition: background 0.3s;
        }}
        .user-bar .logout-btn:hover {{
            background: rgba(255,255,255,0.3);
        }}
    </style>
</head>
<body>
    <div class="user-bar">
        <div class="user-info">
            <span class="user-icon">👤</span>
            <span>Conectado como: <strong>{username}</strong></span>
        </div>
        <a href="/docs/logout" class="logout-btn">Cerrar Sesión</a>
    </div>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {{
            SwaggerUIBundle({{
                url: "{openapi_url}",
                dom_id: '#swagger-ui',
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                layout: "StandaloneLayout",
                persistAuthorization: {'true' if persist_authorization else 'false'},
                withCredentials: {'true' if persist_authorization else 'false'},
            }});
        }};
    </script>
</body>
</html>
"""


def _merge_openapi_components(target: dict, source: dict) -> None:
    if not source:
        return

    if "components" not in target:
        target["components"] = {}

    for key, value in source.get("components", {}).items():
        if not isinstance(value, dict):
            continue
        if key not in target["components"]:
            target["components"][key] = {}
        for name, schema in value.items():
            target["components"][key].setdefault(name, schema)


def _merge_openapi_tags(target: dict, source: dict) -> None:
    source_tags = source.get("tags", []) or []
    if not source_tags:
        return

    target_tags = target.get("tags", []) or []
    existing = {tag.get("name") for tag in target_tags if isinstance(tag, dict)}

    for tag in source_tags:
        tag_name = tag.get("name") if isinstance(tag, dict) else None
        if tag_name and tag_name not in existing:
            target_tags.append(tag)
            existing.add(tag_name)

    if target_tags:
        target["tags"] = target_tags


def _merge_openapi_paths(target: dict, source: dict, prefix: str) -> None:
    for path, methods in source.get("paths", {}).items():
        prefixed_path = f"{prefix}{path}" if prefix else path
        target.setdefault("paths", {})[prefixed_path] = methods


def _merge_openapi_schemas(
    base_schema: dict, mounted_apps: Iterable[Tuple[str, "FastAPI"]]
) -> dict:
    merged = base_schema.copy()
    merged.setdefault("paths", {})

    for prefix, subapp in mounted_apps:
        sub_schema = subapp.openapi()
        _merge_openapi_paths(merged, sub_schema, prefix)
        _merge_openapi_components(merged, sub_schema)
        _merge_openapi_tags(merged, sub_schema)

    return merged


def setup_docs_auth(app, mounted_apps: Optional[Iterable[Tuple[str, "FastAPI"]]] = None):
    """
    Configura la autenticación para la documentación.
    """

    @app.get("/docs", include_in_schema=False)
    async def custom_swagger_ui(request: Request):
        """Swagger UI personalizado con autenticación."""
        username = get_current_docs_user(request)
        if not username:
            return RedirectResponse(url="/docs/login", status_code=302)

        return HTMLResponse(
            get_swagger_ui_html(
                openapi_url="/docs/openapi.json",
                title=f"{app.title} - Documentación",
                username=username,
                persist_authorization=(username == "elparking"),
            )
        )

    @app.get("/docs/openapi.json", include_in_schema=False)
    async def custom_openapi(request: Request):
        """OpenAPI schema filtrado según permisos del usuario."""
        username = get_current_docs_user(request)
        if not username:
            raise HTTPException(status_code=401, detail="No autenticado")

        full_schema = app.openapi()
        if mounted_apps:
            full_schema = _merge_openapi_schemas(full_schema, mounted_apps)

        allowed_tags = get_user_allowed_tags(username)
        filtered_schema = filter_openapi_by_tags(full_schema, allowed_tags)

        return JSONResponse(content=filtered_schema)

    @app.get("/docs/login", include_in_schema=False)
    async def docs_login_page(request: Request, error: str = None):
        """Página de login para la documentación."""
        error_html = ""
        if error:
            error_html = f'<div class="error">{error}</div>'

        html = LOGIN_PAGE_HTML.replace("{error_message}", error_html)
        return HTMLResponse(content=html)

    @app.post("/docs/login", include_in_schema=False)
    async def docs_login(username: str = Form(...), password: str = Form(...)):
        """Procesar el login de la documentación."""
        if username not in DOCS_USERS:
            return RedirectResponse(
                url="/docs/login?error=Usuario o contraseña incorrectos",
                status_code=302,
            )

        if DOCS_USERS[username]["password"] != password:
            return RedirectResponse(
                url="/docs/login?error=Usuario o contraseña incorrectos",
                status_code=302,
            )

        # Crear cookie firmada con el username (funciona con múltiples workers)
        signed_username = sign_value(username)

        response = RedirectResponse(url="/docs", status_code=302)
        response.set_cookie(
            key="docs_session",
            value=signed_username,
            httponly=True,
            max_age=86400,
            samesite="lax",
            secure=IS_PRODUCTION,  # Solo HTTPS en producción
        )
        return response

    @app.get("/docs/logout", include_in_schema=False)
    async def docs_logout(request: Request):
        """Cerrar sesión de la documentación."""
        response = RedirectResponse(url="/docs/login", status_code=302)
        response.delete_cookie("docs_session")
        return response
