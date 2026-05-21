from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime


class MailAccessToken(SQLModel, table=True):
    __tablename__ = "mail_access_token"

    id: Optional[int] = Field(default=None, primary_key=True)
    tokenable_type: str
    id_app: int
    name: str
    token: str
    abilities: Optional[str] = None
    last_used_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
