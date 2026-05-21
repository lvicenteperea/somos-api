from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List, TYPE_CHECKING
from datetime import datetime
from enum import Enum

# Importaciones para type checking (evita importaciones circulares)
if TYPE_CHECKING:
    from app.models.mat_matricula import MatMatricula


class TipoAplicacionEnum(str, Enum):
    NORMAL = "0"  # Normal
    ADMINISTRADOR = "1"  # Administradores de cualquier aplicación


class SomosAplicacion(SQLModel, table=True):
    __tablename__ = "somos_aplicaciones"

    id: Optional[int] = Field(default=None, primary_key=True, description="ID único de la aplicación")
    
    tipo: TipoAplicacionEnum = Field(
        default=TipoAplicacionEnum.NORMAL,
        description="Tipo de aplicación: 0 -> Normal; 1 -> Administradores de cualquier aplicación"
    )
    
    nombre: str = Field(
        max_length=255,
        description="Nombre de la aplicación"
    )
    
    logo: Optional[str] = Field(
        default=None,
        description="Logo de la aplicación (texto/URL)"
    )
    
    public_key: Optional[str] = Field(
        default=None,
        max_length=45,
        description="Clave pública de la aplicación"
    )
    
    private_key: Optional[str] = Field(
        default=None,
        max_length=45,
        description="Clave privada de la aplicación"
    )
    
    created_at: Optional[datetime] = Field(
        default_factory=datetime.now,
        description="Fecha y hora de creación del registro"
    )
    
    updated_at: Optional[datetime] = Field(
        default=None,
        description="Fecha y hora de última actualización del registro"
    )
    
    modified_by: Optional[str] = Field(
        default=None,
        max_length=45,
        description="Usuario que modificó por última vez el registro"
    )

    # Relaciones comentadas temporalmente para evitar problemas de inicialización
    # matriculas: List["MatMatricula"] = Relationship(
    #     back_populates="aplicacion",
    #     sa_relationship_kwargs={"lazy": "select"}
    # )

    # Configuración del modelo
    class Config:
        # Permite usar enums en la serialización
        use_enum_values = True
        # Configuración JSON schema
        json_schema_extra = {
            "example": {
                "tipo": "0",
                "nombre": "Mi Aplicación",
                "logo": "https://ejemplo.com/logo.png",
                "public_key": "public_key_example",
                "private_key": "private_key_example",
                "modified_by": "admin"
            }
        }
