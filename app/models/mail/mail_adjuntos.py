from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime


class MailAdjunto(SQLModel, table=True):
    __tablename__ = "mail_adjuntos"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_envio: Optional[int] = None
    url: str
    nombre_fichero: str
    long_fichero: Optional[float] = None
    mime_type: Optional[str] = None
    extension: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = None
