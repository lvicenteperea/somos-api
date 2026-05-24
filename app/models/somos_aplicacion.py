from datetime import datetime
from enum import Enum
from typing import Optional

from sqlmodel import Field, SQLModel


class TipoAplicacionEnum(str, Enum):
    NORMAL = "0"
    ADMINISTRADOR = "1"


class SomosAplicacion(SQLModel, table=True):
    __tablename__ = "hxxi_aplicaciones"

    id: Optional[int] = Field(default=None, primary_key=True)
    tipo: TipoAplicacionEnum = Field(default=TipoAplicacionEnum.NORMAL)
    nombre: str = Field(max_length=255)
    logo: Optional[str] = None
    public_key: Optional[str] = Field(default=None, max_length=45)
    private_key: Optional[str] = Field(default=None, max_length=45)
    created_at: Optional[datetime] = Field(default_factory=datetime.now)
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = Field(default=None, max_length=45)

    model_config = {
        "use_enum_values": True,
        "json_schema_extra": {
            "example": {
                "tipo": "0",
                "nombre": "Mi Aplicacion",
                "logo": "https://ejemplo.com/logo.png",
                "public_key": "public_key_example",
                "private_key": "private_key_example",
                "modified_by": "admin",
            }
        },
    }
