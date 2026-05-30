from datetime import timedelta

from passlib.context import CryptContext
from sqlalchemy import select
from sqlmodel import Session

from app.config.settings import settings
from app.middlewares.jwt_auth import create_access_token
from app.models.api_usuarios import ApiUsuario

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password, hashed_password):
    """Verifica si una contrasena en texto plano coincide con su hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password):
    """Genera un hash para una contrasena en texto plano."""
    return pwd_context.hash(password)


async def authenticate_user(db: Session, username: str, password: str, slug: str):
    query = select(ApiUsuario).where(ApiUsuario.username == username)
    result = db.execute(query)
    user = result.scalar_one_or_none()

    if not user or not verify_password(password, user.hashed_password):
        print(f"Authenticating user: {username}, found user: {user}. pwd{password}")
        return None
    
    print(f"Authenticating user: {username}, found user: {user}")

    return user or 'Token de prueba'


async def get_jwt_token(db: Session, username: str, password: str, slug: str):
    user = await authenticate_user(db, username, password, slug)
    if not user:
        return None

    access_token_expires = timedelta(
        minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
    )
    access_token = create_access_token(
        data={"sub": user.username},
        expires_delta=access_token_expires,
    )
    return {"bearer": access_token}


def allow_anonymous(fn):
    setattr(fn, "allow_anonymous", True)
    return fn
