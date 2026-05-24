from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime
from cryptography.fernet import Fernet
import json

from app.config.settings import settings


def get_fernet() -> Fernet:
    key = settings.API_PAYMENTS_KEY
    if not key:
        raise ValueError("API_PAYMENTS_KEY no definido en el entorno")
    return Fernet(key)


class MailServidor(SQLModel, table=True):
    __tablename__ = "mail_servidores"

    id: Optional[int] = Field(default=None, primary_key=True)
    nombre: str
    charset: str = "utf8"
    descripcion: Optional[str] = None
    nombre_clase: str
    nombre_servicio: str
    orden_servidor: int
    de: str
    de_nombre: str
    reply_to: str
    ip: Optional[str] = None
    puerto: str
    host: str
    usuario: str
    password: str
    credenciales: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = None

    @property
    def credentials_dict(self) -> dict:
        if not self.credenciales:
            return {}
        fernet = get_fernet()
        try:
            decrypted = fernet.decrypt(self.credenciales.encode("utf-8"))
            return json.loads(decrypted.decode("utf-8"))
        except Exception as e:
            raise ValueError("Error al descifrar las credenciales") from e

    @credentials_dict.setter
    def credentials_dict(self, value: dict):
        fernet = get_fernet()
        json_data = json.dumps(value)
        encrypted = fernet.encrypt(json_data.encode("utf-8"))
        self.credenciales = encrypted.decode("utf-8")
