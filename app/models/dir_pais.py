from typing import Optional, List
from datetime import datetime
from sqlmodel import Field, SQLModel, Relationship


class DirPais(SQLModel, table=True):
    """
    Modelo para la tabla dir_paises.
    Representa un país con su información básica.
    """
    
    __tablename__ = "dir_paises"
    
    id: Optional[int] = Field(
        default=None, 
        primary_key=True, 
        sa_column_kwargs={"autoincrement": True, "nullable": False, "type": "BIGINT UNSIGNED"}
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
    # comunidades: List["Comunidad"] = Relationship(back_populates="pais")
