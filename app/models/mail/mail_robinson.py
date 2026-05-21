from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime


class MailRobinson(SQLModel, table=True):
    __tablename__ = "mail_robinson"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_app: int
    email: str
    nivel: str  # Enum: 'M', 'P', 'T'
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = None
