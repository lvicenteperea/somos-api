from abc import ABC, abstractmethod
from typing import Dict, List

from app.models.mail.mail_envios import MailEnvio


class MailingProvider(ABC):
    """Contrato comun para proveedores de envio de correo."""

    def _looks_like_html(self, content: str) -> bool:
        if not content:
            return False

        lowered = content.lower()
        if "<html" in lowered or "<body" in lowered or "<table" in lowered:
            return True

        import re

        return bool(re.search(r"<[a-z][\s\S]*?>", content))

    @abstractmethod
    def set_credentials(self, credentials: Dict[str, str]):
        pass

    @abstractmethod
    def send_mail(
        self,
        envio: MailEnvio,
        render_subject: str,
        render_body: str,
        adjuntos: List[str],
    ) -> Dict[str, object]:
        pass
