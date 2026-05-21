from sqlmodel import SQLModel, Field
from typing import Optional, List
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import text
import json


class MailEnvio(SQLModel, table=True):
    __tablename__ = "mail_envios"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_app: int
    id_sender: int
    id_servidor: int
    id_participante: int
    estado: str  # Enum: 'P', 'E', 'R', 'O', 'L'
    para: Optional[str] = None
    para_nombre: Optional[str] = None
    de: str
    de_nombre: Optional[str] = None
    cc: Optional[str] = None
    bcc: Optional[str] = None
    prioridad: int = 3
    reply_to: Optional[str] = None
    clave_externa: Optional[str] = None
    asunto: str
    cuerpo: str
    lenguaje: str
    parametros: Optional[str] = None
    fecha_envio: datetime
    fecha_enviado: Optional[datetime] = None
    error: Optional[str] = None
    identificador_externo: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = None
