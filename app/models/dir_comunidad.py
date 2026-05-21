from typing import Optional, List
from datetime import datetime
from sqlmodel import Field, SQLModel, Relationship


class DirComunidad(SQLModel, table=True):
    """
    Modelo para la tabla dir_comunidades.
    Representa una comunidad autónoma con su información administrativa.
    """
    
    __tablename__ = "dir_comunidades"
    
    id: Optional[int] = Field(
        default=None, 
        primary_key=True, 
        sa_column_kwargs={"autoincrement": True, "nullable": False, "type": "BIGINT UNSIGNED"}
    )
    id_pais: int = Field(
        foreign_key="dir_paises.id",
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
    # pais: Optional["Pais"] = Relationship(back_populates="comunidades")
    # provincias: List["Provincia"] = Relationship(back_populates="comunidad")
