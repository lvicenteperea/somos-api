from typing import Optional, List
from datetime import datetime
from enum import Enum
from sqlmodel import Field, SQLModel, Relationship


class TipoDireccion(str, Enum):
    PRINCIPAL = "1"
    OTRAS = "2"
    FISCAL = "3"


class DirDireccion(SQLModel, table=True):
    """
    Modelo para la tabla dir_direcciones.
    Representa una dirección postal con sus detalles completos.
    """
    
    __tablename__ = "dir_direcciones"
    
    id: Optional[int] = Field(
        default=None, 
        primary_key=True, 
        sa_column_kwargs={"autoincrement": True, "nullable": False, "type": "BIGINT UNSIGNED"}
    )
    tipo: TipoDireccion = Field(
        default=TipoDireccion.PRINCIPAL,
        sa_column_kwargs={"type": "SET('1','2','3')"},
        description="1 --> principal; 2 --> otras; 3 --> Fiscal,...."
    )
    id_propietario: Optional[int] = Field(
        default=None, 
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    tipo_propietario: Optional[int] = Field(
        default=None, 
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    id_provincia: int = Field(
        foreign_key="dir_provincias.id", 
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    id_ciudad: int = Field(
        foreign_key="dir_ciudades.id", 
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    localidad: str = Field(max_length=255)
    cp: str = Field(max_length=25)
    direccion1: str = Field(max_length=255)
    direccion2: Optional[str] = Field(default=None, max_length=255)
    numero: Optional[str] = Field(default=None, max_length=15)
    complemento: Optional[str] = Field(default=None, max_length=15)
    portal_bloque: Optional[str] = Field(default=None, max_length=15)
    escalera: Optional[str] = Field(default=None, max_length=15)
    planta: Optional[str] = Field(default=None, max_length=15)
    puerta: Optional[str] = Field(default=None, max_length=15)
    created_at: datetime = Field(
        default_factory=datetime.utcnow,
        sa_column_kwargs={"server_default": "CURRENT_TIMESTAMP"}
    )
    updated_at: Optional[datetime] = Field(
        default=None,
        sa_column_kwargs={"onupdate": datetime.utcnow}
    )
    modified_by: Optional[str] = Field(default=None, max_length=45)
