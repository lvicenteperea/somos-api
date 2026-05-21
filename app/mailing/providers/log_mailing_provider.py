import logging
import json
from typing import Dict, List
from app.models.mail.mail_envios import MailEnvio
from .mailing_provider import MailingProvider

logger = logging.getLogger("log_mail_provider")
logger.setLevel(logging.INFO)

class LogMailingProvider(MailingProvider):
    def __init__(self):
        self.credentials = {}

    def set_credentials(self, credentials: Dict[str, str]):
        self.credentials = credentials  # Guardamos por si se quiere registrar también

    def send_mail(self, envio: MailEnvio, render_subject: str, adjuntos: List[str] = None):
        mail_log = {
            "de": envio.de,
            "de_nombre": envio.de_nombre,
            "para": envio.para,
            "para_nombre": envio.para_nombre,
            "cc": envio.cc,
            "bcc": envio.bcc,
            "reply_to": envio.reply_to,
            "asunto": envio.asunto,
            "cuerpo": envio.cuerpo,
            "lenguaje": envio.lenguaje,
            "prioridad": envio.prioridad,
            "adjuntos": adjuntos or [],
            "clave_externa": envio.clave_externa,
            "identificador_externo": envio.identificador_externo,
            "credenciales": self.credentials
        }

        logger.info(f"[MAIL-LOG] Email simulado:\n{json.dumps(mail_log, indent=2, ensure_ascii=False)}")
