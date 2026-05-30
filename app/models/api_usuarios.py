from typing import Optional
from sqlmodel import Field, SQLModel, Relationship

class ApiUsuario(SQLModel, table=True):
    __tablename__ = "api_usuarios"

    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)
    email: str = Field(unique=True, index=True)
    hashed_password: str
    is_active: bool = Field(default=True)
    token_expire_time: Optional[int] = Field(
        default=999999,
        description="Tiempo de expiración del token en segundos (default: 999999)"
    )
