from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Request, status
from fastapi.responses import JSONResponse
from jose import JWTError, jwt
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.routing import Match

from app.config.settings import settings

SECRET_KEY = settings.JWT_SECRET_KEY
ALGORITHM = settings.JWT_ALGORITHM
ACCESS_TOKEN_EXPIRE_MINUTES = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES


class JWTBearer(BaseHTTPMiddleware):
    """Middleware para verificar tokens JWT en rutas protegidas."""

    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        endpoint = None

        try:
            for route in request.app.router.routes:
                match, _ = route.matches(request.scope)
                if match == Match.FULL:
                    endpoint = getattr(route, "endpoint", None)
                    break
        except Exception:
            endpoint = None

        if endpoint and getattr(endpoint, "allow_anonymous", False):
            return await call_next(request)

        requires_auth = path.startswith("/bo") and not path.endswith("/auth")
        if settings.DEVELOPMENT:
            requires_auth = False

        if requires_auth:
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
                username = payload.get("sub")
                if username is None:
                    return self._unauthorized_response("Invalid token payload")
                request.state.user = username
            except JWTError:
                return self._unauthorized_response("Invalid token or token expired")
            except Exception:
                return self._unauthorized_response("Authentication failed")

        return await call_next(request)

    def _unauthorized_response(self, detail: str):
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": detail},
            headers={"WWW-Authenticate": "Bearer"},
        )


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
