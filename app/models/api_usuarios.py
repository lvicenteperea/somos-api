from typing import Optional
from sqlmodel import Field, SQLModel, Relationship

class ApiUsuario(SQLModel, table=True):
    __tablename__ = "api_usuarios"

    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)
    email: str = Field(unique=True, index=True)
    hashed_password: str
    is_active: bool = Field(default=True)
    id_partner: Optional[int] = Field(default=None, foreign_key="pat_partners.id")
    id_sistema_control: Optional[int] = Field(
        default=None, 
        foreign_key="mae_sistemas_control.id",
        description="ID del sistema de control asociado al usuario API"
    )
    token_expire_time: Optional[int] = Field(
        default=999999,
        description="Tiempo de expiración del token en segundos (default: 999999)"
    )

    # Relaciones (opcionales, agregar según necesidad)
    # partner: "PatPartner" = Relationship(back_populates="api_usuarios")
    # sistema_control: "MaeSistemasControl" = Relationship(back_populates="api_usuarios")