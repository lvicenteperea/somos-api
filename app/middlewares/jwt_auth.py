from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from jose import jwt, JWTError
from typing import Optional, Callable
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.routing import Match
from app.utils.dates import ahora

# Cargar las variables de entorno
load_dotenv()

# Configuración de JWT
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "tu_clave_secreta_muy_segura_aqui")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
DEVELOPMENT = os.getenv("DEVELOPMENT", "0") == "1"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

class JWTBearer(BaseHTTPMiddleware):
    """
    Middleware para verificar tokens JWT en rutas protegidas.
    """

    async def dispatch(self, request: Request, call_next):
        path = request.url.path

        # Intenta resolver la ruta actual y obtener su endpoint
        endpoint = None
        try:
            # Itera por las rutas registradas y busca coincidencia FULL con método + path
            for route in request.app.router.routes:
                match, _ = route.matches(request.scope)
                if match == Match.FULL:
                    endpoint = getattr(route, "endpoint", None)
                    break
        except Exception:
            endpoint = None  # Si no se puede resolver, seguimos con los prefijos

        # Si el endpoint está marcado como público, no pedimos token
        if endpoint and getattr(endpoint, "allow_anonymous", False):
            return await call_next(request)

        # A partir de aquí, aplica tu política habitual por prefijo
        requires_auth = (
                (path.startswith("/parkings-admin") and not path.endswith("/auth")) or
                (path.startswith("/bo") and not path.endswith("/auth"))
        )

        if DEVELOPMENT:
            requires_auth = False

        if requires_auth:
            # === Verificación estándar Bearer ===
            auth_header = request.headers.get("Authorization")
            if not auth_header:
                return self._unauthorized_response("No Authorization header provided")

            try:
                scheme, token = auth_header.split()
            except ValueError:
                return self._unauthorized_response("Invalid Authorization header format")

            if scheme.lower() != "bearer":
                return self._unauthorized_response("Invalid authentication scheme")

            try:
                payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                username: str = payload.get("sub")
                if username is None:
                    return self._unauthorized_response("Invalid token payload")
                request.state.user = username
            except JWTError:
                return self._unauthorized_response("Invalid token or token expired")
            except Exception:
                return self._unauthorized_response("Authentication failed")

        # Si no requiere auth o ya superó el check
        return await call_next(request)

    def _unauthorized_response(self, detail: str):
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": detail},
            headers={"WWW-Authenticate": "Bearer"}
        )

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """
    Crear un token JWT para un usuario.
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))  # JWT requiere UTC (validado por jose contra UTC)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
