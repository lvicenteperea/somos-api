from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime


class MailAplicacion(SQLModel, table=True):
    __tablename__ = "mail_aplicaciones"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_app: int
    descripcion: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = None
