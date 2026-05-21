from typing import Optional
from datetime import datetime
from sqlmodel import Field, SQLModel, Relationship


class DirCiudad(SQLModel, table=True):
    """
    Modelo para la tabla dir_ciudades.
    Representa una ciudad con su información geográfica.
    """
    
    __tablename__ = "dir_ciudades"
    
    id: Optional[int] = Field(
        default=None, 
        primary_key=True, 
        sa_column_kwargs={"autoincrement": True, "nullable": False, "type": "BIGINT UNSIGNED"}
    )
    name: Optional[str] = Field(default=None, max_length=100)
    id_provincia: Optional[int] = Field(
        default=None, 
        foreign_key="dir_provincias.id",
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    slug: Optional[str] = Field(default=None, max_length=100)
    latitud: Optional[float] = Field(default=None)
    longitud: Optional[float] = Field(default=None)
    created_at: datetime = Field(
        default_factory=datetime.utcnow,
        sa_column_kwargs={"server_default": "CURRENT_TIMESTAMP"}
    )
    updated_at: Optional[datetime] = Field(
        default=None,
        sa_column_kwargs={"onupdate": datetime.utcnow}
    )
    
    # Relaciones (opcional, si estás utilizando relaciones en SQLModel)
    # provincia: Optional["Provincia"] = Relationship(back_populates="ciudades")
    # direcciones: List["Direccion"] = Relationship(back_populates="ciudad")
