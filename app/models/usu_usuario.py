from typing import Optional
from datetime import datetime
from enum import Enum
from sqlmodel import Field, SQLModel, Relationship


class EstadoUsuario(str, Enum):
    ACTIVO = "A"
    BAJA = "B"
    PENDIENTE = "P"


class UsuUsuario(SQLModel, table=True):
    """
    Modelo para la tabla usu_usuarios.
    Representa un usuario del sistema con acceso a las aplicaciones.
    """
    
    __tablename__ = "usu_usuarios"
    
    id: Optional[int] = Field(
        default=None, 
        primary_key=True, 
        foreign_key="mae_tipos_usuario.id",
        sa_column_kwargs={"autoincrement": True, "nullable": False, "type": "BIGINT UNSIGNED"}
    )
    id_app: int = Field(
        foreign_key="somos_aplicaciones.id",
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    id_tipo_usuario: int = Field(
        sa_column_kwargs={"type": "BIGINT UNSIGNED"},
        description="Usuario (No empleado, no cliente...), Empleado, Cliente, Colaborador, Partners, API..."
    )
    name: str = Field(max_length=100)
    email: str = Field(max_length=100)
    email_verified_at: Optional[datetime] = Field(
        default=None,
        description="fecha en la que se ha verificado el email y por lo tanto pasa de estado 'P' a 'A'. Puede tener esta fecha y estar de baja, pero si no la tiene ha de estar en estado 'P'"
    )
    estado: EstadoUsuario = Field(
        default=EstadoUsuario.BAJA,
        sa_column_kwargs={"type": "ENUM('A','B','P')"},
        description="""Activo: ya se ha dado de alta y confirmado el correo; 
        Baja: Se le ha dado de baja por el motivo que sea; 
        Pendiente de confirmar correo: Se ha dado de alta pero no ha confirmado el correo o ha cambiado de correo y no lo ha confirmado (No puede entrar en la aplicación)"""
    )
    password: str = Field(max_length=255)
    desde: datetime = Field()
    hasta: Optional[datetime] = Field(default=None)
    created_at: datetime = Field(
        default_factory=datetime.utcnow,
        sa_column_kwargs={"server_default": "CURRENT_TIMESTAMP"}
    )
    updated_at: Optional[datetime] = Field(default=None)
    modified_by: Optional[str] = Field(default=None, max_length=45)
    deleted_at: Optional[datetime] = Field(default=None)
    
    # Relaciones (opcional, si estás utilizando relaciones en SQLModel)
    # tipo_usuario: Optional["TipoUsuario"] = Relationship(back_populates="usuarios")
    # aplicacion: Optional["Aplicacion"] = Relationship(back_populates="usuarios")
    # empleado: Optional["Empleado"] = Relationship(back_populates="usuario")
