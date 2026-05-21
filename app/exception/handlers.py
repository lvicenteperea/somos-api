import traceback
from datetime import date, datetime

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.utils.call_db_procedure import CoreDatabaseException
from app.utils.logging import crea_log

# ──────────────────────────────────────────────────────────────────────────────
def make_json_safe(value):
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: make_json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [make_json_safe(v) for v in value]
    if isinstance(value, tuple):
        return [make_json_safe(v) for v in value]
    return value


async def _build_request_context(request: Request) -> str:
    """Construye un string de contexto con los datos del request para el log."""
    params = {
        "method": request.method,
        "path": request.url.path,
        "client": request.client.host if request.client else "unknown",
        "user_agent": request.headers.get("user-agent", "")[:100],
    }
    if request.query_params or request.method in ("GET", "DELETE", "HEAD"):
        params["query"] = str(request.query_params) if request.query_params else ""
    else:
        body = await request.body()
        if body:
            try:
                params["body"] = body.decode("utf-8", errors="replace")[:2000]
            except Exception:
                params["body"] = "<unreadable>"
    return str({"Parametros": params})


# ──────────────────────────────────────────────────────────────────────────────
async def core_exception_handler(request: Request, exc: Exception):
    path = request.url.path
    status_code = getattr(exc, "status_code", 500)

    # ── Construir payload de respuesta ──────────────────────────────────────
    if isinstance(exc, CoreDatabaseException):
        ret = exc.to_dict()
        if path.startswith("/parkings-admin"):
            payload = {"detail": ret.get("detail"), "slug": ret.get("slug"), "text_cli": ret.get("text_cli")}
        elif path.startswith("/bo"):
            payload = {"detail": ret.get("detail"), "slug": ret.get("slug"), "log": ret.get("log"), "text_cli": ret.get("text_cli")}
        else:
            payload = {"detail": ret.get("detail", "Error")}

    elif isinstance(exc, HTTPException):
        if path.startswith("/parkings-admin"):
            payload = {"detail": exc.detail, "slug": exc.detail, "text_cli": exc.detail}
        elif path.startswith("/bo"):
            payload = {"detail": exc.detail, "slug": exc.detail, "log": exc.detail, "text_cli": exc.detail}
        else:
            payload = {"detail": exc.detail}

    elif isinstance(exc, RequestValidationError):
        detail = exc.errors()
        status_code = 422
        if path.startswith("/parkings-admin"):
            payload = {"detail": detail, "slug": "VALIDATION_ERROR", "text_cli": "Datos inválidos"}
        elif path.startswith("/bo"):
            payload = {"detail": detail, "slug": "VALIDATION_ERROR", "log": str(exc), "text_cli": "Datos inválidos"}
        else:
            payload = {"detail": detail}

    else:
        if path.startswith("/parkings-admin"):
            payload = {"detail": "Hubo un error inesperado", "slug": "INTERNAL_SERVER_ERROR", "text_cli": "Hubo un error inesperado"}
        elif path.startswith("/bo"):
            payload = {"detail": "Hubo un error inesperado", "slug": "INTERNAL_SERVER_ERROR", "log": str(exc), "text_cli": "Hubo un error inesperado"}
        else:
            payload = {"detail": "Hubo un error inesperado"}

    # ── Log automático para errores de servidor (5xx) ───────────────────────
    if status_code >= 500:
        try: 
            tb = traceback.format_exc()
            await crea_log(
                v_log=await _build_request_context(request),
                v_user="core_exception_handler",
                v_tipo="E",
                v_accion="2",
                v_mysql_errno=path[:150],
                v_returned_sqlstate="ex_controladas",
                v_message_text=f"{type(exc).__name__}: {exc}\n{tb}"[:4000],
                v_ret_txt='{"slug": "INTERNAL_SERVER_ERROR", "txt_cli": "Error interno del servidor"}',
            )
        except Exception:
            pass  # El logger NUNCA puede romper la respuesta al cliente

    return JSONResponse(status_code=status_code, content=make_json_safe(payload))
