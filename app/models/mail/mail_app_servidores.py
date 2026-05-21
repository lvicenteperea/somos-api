from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime


class MailAppServidor(SQLModel, table=True):
    __tablename__ = "mail_app_servidores"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_app: int
    id_servidor: int
    tipo: str  # Enum: 'M', 'P', 'T'
    activo: str  # Enum: 'S', 'N'
    orden_servidor: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = None
