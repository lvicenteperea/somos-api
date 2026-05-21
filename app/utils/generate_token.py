import random
import string
from typing import Type
from sqlmodel import SQLModel, Session
from sqlmodel.ext.asyncio.session import AsyncSession
from sqlalchemy import select
from app.config.db import get_db


def generate_unique_id(session: Session, model, min_id=100000, max_id=999999) -> int:
    for _ in range(10):  # intenta 10 veces como máximo
        new_id = random.randint(min_id, max_id)
        exists = session.get(model, new_id)
        if not exists:
            return new_id
    raise ValueError("No se pudo generar un ID único después de varios intentos.")


def generate_token(
    session: Session,
    model: Type[SQLModel],
    token_field: str,
    length: int = 12,
    charset: str = string.ascii_letters + string.digits,
    max_attempts: int = 100
) -> str:
    """
    Genera un token aleatorio único que no esté repetido en la base de datos.

    :param session: Sesión activa de la base de datos.
    :param model: Clase del modelo SQLModel.
    :param token_field: Nombre del campo del modelo que contiene el token.
    :param length: Longitud del token.
    :param charset: Caracteres permitidos en el token.
    :param max_attempts: Máximo número de intentos para evitar colisiones.
    :return: Token único.
    :raises ValueError: Si no se puede generar un token único.
    """
    for _ in range(max_attempts):
        token = ''.join(random.choices(charset, k=length))
        stmt = select(model).where(getattr(model, token_field) == token)
        result = session.execute(stmt)
        row = result.first()

        if row is None:
            return token

    raise ValueError(f"No se pudo generar un token único después de {max_attempts} intentos.")

async def generate_token_no_verification(
    length: int = 12,
    charset: str = string.ascii_letters + string.digits
) -> str:

    token = ''.join(random.choices(charset, k=length))
    return token

