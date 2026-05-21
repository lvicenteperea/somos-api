# app/mailing/providers/mailing_provider.py
from abc import ABC, abstractmethod
from typing import Dict, Optional, List, Any
from sqlmodel import Session, select
from app.models.mail.mail_envios import MailEnvio
from app.models.mail.mail_adjuntos import MailAdjunto
import json, re, os

_PARAM_PATTERN = re.compile(r"{{\s*([a-zA-Z0-9_.-]+)\s*}}")

class MailingProvider(ABC):
    """
    Proveedor abstracto para envío de correos.
    Ofrece helpers comunes para renderizar el cuerpo y recuperar adjuntos.
    """

    def __init__(self) -> None:
        pass

    def _looks_like_html(self, content: str) -> bool:
        if not content:
            return False
        # señales fuertes:
        lowered = content.lower()
        if "<html" in lowered or "<body" in lowered or "<table" in lowered:
            return True
        # patrón de etiquetas HTML no-escapeadas
        import re
        return bool(re.search(r"<[a-z][\s\S]*?>", content))

    @abstractmethod
    def set_credentials(self, credentials: Dict[str, str]):
        pass

    @abstractmethod
    def send_mail(self, envio: MailEnvio, render_subject: str, render_body: str, adjuntos: List[str])  -> Dict[str, object]:
        """No recibe adjuntos; cada provider debe obtenerlos con los helpers."""
        pass
