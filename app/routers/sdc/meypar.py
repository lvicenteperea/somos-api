import os

from fastapi import APIRouter, status, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.config.db import get_db
from app.schemas.auth import LoginRequest, AuthResponse
from app.utils.auth import get_jwt_token

router = APIRouter(prefix="/sdc/meypar/api", tags=["meypar"])


@router.post(
    "/auth",
    response_model=AuthResponse,
    summary="Autenticación de usuario Meypar",
    description="Autentica al usuario con sus credenciales (username y password) y devuelve un token JWT Bearer para usar en las siguientes peticiones.",
)
async def login(
    login_data: LoginRequest, db: AsyncSession = Depends(get_db)
) -> AuthResponse:
    """
    Endpoint para autenticar al usuario y devolver un token JWT.
    """
    token_data = await get_jwt_token(
        db,
        login_data.username,
        login_data.password,
        os.environ.get("MEYPAR_SLUG", "meypar"),
    )

    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username or password incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return JSONResponse(status_code=status.HTTP_200_OK, content=token_data)
