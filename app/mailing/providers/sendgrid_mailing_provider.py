import os
import base64
import mimetypes
import logging
from typing import Dict, List, Tuple

import sendgrid
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import (
    Mail,
    Personalization,
    To,
    Cc,
    Bcc,
    ReplyTo,
    Attachment,
    FileContent,
    FileName,
    FileType,
    Disposition,
)

from app.models.mail.mail_envios import MailEnvio
from .mailing_provider import MailingProvider

logger = logging.getLogger(__name__)


class SendgridMailingProvider(MailingProvider):
    def __init__(self):
        self.sg: SendGridAPIClient | None = None

    def set_credentials(self, credentials: Dict[str, str]):
        api_key = credentials.get("api_key")
        if not api_key:
            raise ValueError("Falta 'api_key' para SendGrid")
        self.sg = sendgrid.SendGridAPIClient(api_key=api_key)

    def _add_recipients(self, message: Mail, envio: MailEnvio):
        """
        Añade To/CC/BCC usando Personalization según docs SendGrid.
        Acepta listas separadas por coma o listas nativas.
        """

        def normalize(value) -> List[str]:
            if not value:
                return []
            if isinstance(value, (list, tuple)):
                return [str(x).strip() for x in value if str(x).strip()]
            # cadena separada por comas
            return [p.strip() for p in str(value).split(",") if p.strip()]

        tos = normalize(envio.para)
        ccs = normalize(getattr(envio, "cc", None))
        bccs = normalize(getattr(envio, "bcc", None))

        # Eliminar duplicados entre To, Cc, Bcc
        tos_set = set(tos)
        ccs_set = set(ccs) - tos_set
        bccs_set = set(bccs) - tos_set - ccs_set

        tos = list(tos_set)
        ccs = list(ccs_set)
        bccs = list(bccs_set)

        if not tos:
            raise ValueError("Campo 'para' (To) obligatorio no informado")

        # Una personalización con todos los destinatarios
        p = Personalization()
        for addr in tos:
            p.add_to(To(addr))
        for addr in ccs:
            p.add_cc(Cc(addr))
        for addr in bccs:
            p.add_bcc(Bcc(addr))
        message.add_personalization(p)

    def _add_attachments(self, message: Mail, adjuntos: List[str] | None):
        """
        Añade adjuntos usando message.add_attachment(Attachment(...))
        tal como recomiendan los ejemplos oficiales.
        """
        for path in adjuntos or []:
            if not os.path.isfile(path):
                logger.warning(f"Adjunto no encontrado, se omite: {path}")
                continue

            with open(path, "rb") as f:
                data = f.read()
            encoded = base64.b64encode(data).decode()

            ctype, _ = mimetypes.guess_type(path)
            ctype = ctype or "application/octet-stream"

            basename = os.path.basename(path)
            cid = None
            filename = basename

            # Formato especial para inline: cid__<cid>__nombre.png
            if basename.startswith("cid__"):
                parts = basename.split("__", 2)
                if len(parts) == 3:
                    _, cid, filename = parts

            disposition = "inline" if cid else "attachment"

            attachment = Attachment(
                FileContent(encoded),
                FileName(filename),
                FileType(ctype),
                Disposition(disposition),
            )

            if cid:
                attachment.content_id = cid

            message.add_attachment(attachment)

    def send_mail(
        self,
        envio: MailEnvio,
        render_subject: str,
        render_body: str,
        adjuntos: List[str],
    ) -> Dict[str, object]:
        if not self.sg:
            raise RuntimeError(
                "SendGrid no está inicializado. Llama a set_credentials primero."
            )

        if not envio.de:
            raise ValueError("Campo 'de' (From) obligatorio no informado")

        # Cuerpo: si viene HTML explícito, lo ponemos en html_content
        is_html = self._looks_like_html(render_body)
        html = (render_body or "") if is_html else None
        plain = (
            (render_body or "")
            if not is_html
            else "Este correo requiere un visor HTML."
        )

        message = Mail(
            from_email=envio.de,
            subject=render_subject,
            html_content=html,
            plain_text_content=plain,
        )

        # Reply-To si procede
        if getattr(envio, "reply_to", None):
            message.reply_to = ReplyTo(envio.reply_to)

        # Cabeceras custom (p. ej. X-Clave-Externa)
        # if getattr(envio, "clave_externa", None):
        #     # Mail.headers es un dict; puedes añadir pares clave-valor
        #     if message.headers is None:
        #         message.headers = {}
        #     message.headers["X-Clave-Externa"] = str(envio.clave_externa)

        # (Opcional) Prioridad: algunos clientes respetan estas cabeceras
        # if getattr(envio, "prioridad", None) == 1:
        #     if message.headers is None:
        #         message.headers = {}
        #     message.headers.update({
        #         "X-Priority": "1",
        #         "Priority": "urgent",
        #         "Importance": "high",
        #     })

        # Destinatarios (To, Cc, Bcc)
        self._add_recipients(
            message, envio
        )  # CC/BCC con Personalization, según guía oficial. :contentReference[oaicite:3]{index=3}

        # Adjuntos
        self._add_attachments(
            message, adjuntos
        )  # Adjuntos base64 + add_attachment. :contentReference[oaicite:4]{index=4}

        # Envío
        try:
            response = self.sg.send(message)
            logger.debug("SendGrid status=%s", response.status_code)

            return {
                "status_code": response.status_code,
                "response_body": (
                    getattr(response, "body", b"").decode("utf-8", errors="ignore")
                    if hasattr(response, "body")
                    and isinstance(response.body, (bytes, bytearray))
                    else getattr(response, "body", "")
                ),
                "response_headers": dict(getattr(response, "headers", {})),
            }
        except Exception as e:
            logger.error(f"Error en envío SendGrid: {e}", exc_info=True)
            raise
