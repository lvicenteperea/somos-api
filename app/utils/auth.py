from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.api_usuarios import ApiUsuario
from app.models.pat_partner import PatPartner
from app.middlewares.jwt_auth import create_access_token
from datetime import timedelta
from typing import Optional
import os
from dotenv import load_dotenv

# Cargar las variables de entorno
load_dotenv()

# Configuración de JWT
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# Configuración para hash de contraseñas
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    """
    Verifica si una contraseña en texto plano coincide con su hash.
    """
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    """
    Genera un hash para una contraseña en texto plano.
    """
    return pwd_context.hash(password)

async def get_partner_id_by_slug(db: AsyncSession, partner_slug: str) -> Optional[int]:
    """
    Obtener el ID del partner a partir de su slug.
    """
    try:
        query = select(PatPartner).where(PatPartner.slug == partner_slug)
        result = db.execute(query)
        partner = result.scalar_one_or_none()
        
        if partner:
            print(f"Partner encontrado: ID={partner.id}, slug={partner.slug}, activo='{partner.activo}'")
            return partner.id
        else:
            print(f"No se encontró partner con slug: {partner_slug}")
            return None
            
    except Exception as e:
        print(f"Error al buscar partner: {e}")
        print(f"Tipo de error: {type(e)}")
        return None


async def authenticate_user(db: AsyncSession, username: str, password: str, slug: str):
    """
    Autenticar un usuario con nombre de usuario y contraseña.
    """
    # Buscar el usuario en la base de datos
    query = select(ApiUsuario).where(
        ApiUsuario.username == username,
    )
    result = db.execute(query)
    user = result.scalar_one_or_none()

    # Obtener el ID del partner a partir del slug
    partner_id = await get_partner_id_by_slug(db, slug)

    if not partner_id:
        return None  # Partner no encontrado
    
    # Verificar si el usuario existe y la contraseña es correcta
    if not user or not verify_password(password, user.hashed_password):
        return None
    
    return user

async def get_jwt_token(db: AsyncSession, username: str, password: str, slug: str):
    """
    Obtener un token JWT para un usuario autenticado.
    
    Args:
        db: Sesión de base de datos
        username: Nombre de usuario
        password: Contraseña
        partner: Slug del partner (ej: "somos", "parkingsadmin", etc.)
    """
    
    # Autenticar al usuario con el partner_id encontrado
    user = await authenticate_user(db, username, password, slug)
    
    if not user:
        return None
    
    # Crear el token JWT
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    
    return {
        "bearer": access_token,
    }


def allow_anonymous(fn):
    setattr(fn, "allow_anonymous", True)
    return fn