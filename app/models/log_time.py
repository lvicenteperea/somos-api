import datetime
from typing import Optional
from sqlmodel import Field, SQLModel

class LogTime(SQLModel, table=True):
    __tablename__ = "somos_log_time"

    id: Optional[int] = Field(default=None, primary_key=True)
    endpoint: Optional[str] = None
    request_date: datetime.datetime = Field(nullable=True)
    duration: Optional[float] = None
    ip: Optional[str] = None
    response_code: Optional[int] = None
