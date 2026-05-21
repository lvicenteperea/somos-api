from typing import Optional, List
from datetime import datetime
from sqlmodel import Field, SQLModel, Relationship


class DirProvincia(SQLModel, table=True):
    """
    Modelo para la tabla dir_provincias.
    Representa una provincia con su información administrativa.
    """
    
    __tablename__ = "dir_provincias"
    
    id: Optional[int] = Field(
        default=None, 
        primary_key=True, 
        sa_column_kwargs={"autoincrement": True, "nullable": False, "type": "BIGINT UNSIGNED"}
    )
    id_comunidad: int = Field(
        foreign_key="dir_comunidades.id",
        default=0,
        sa_column_kwargs={"type": "BIGINT UNSIGNED"}
    )
    codigo: str = Field(max_length=25)
    nombre: str = Field(max_length=255)
    created_at: datetime = Field(
        default_factory=datetime.utcnow,
        sa_column_kwargs={"server_default": "CURRENT_TIMESTAMP"}
    )
    updated_at: Optional[datetime] = Field(
        default=None,
        sa_column_kwargs={"onupdate": datetime.utcnow}
    )
    modified_by: Optional[str] = Field(default=None, max_length=45)
    
    # Relaciones (opcional, si estás utilizando relaciones en SQLModel)
    # comunidad: Optional["Comunidad"] = Relationship(back_populates="provincias")
    # ciudades: List["Ciudad"] = Relationship(back_populates="provincia")
    # direcciones: List["Direccion"] = Relationship(back_populates="provincia")
