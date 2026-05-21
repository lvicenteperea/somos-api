import smtplib
from email.message import EmailMessage
from typing import Dict, List, Tuple
from app.models.mail.mail_envios import MailEnvio
from .mailing_provider import MailingProvider
import mimetypes
import os
import logging

logger = logging.getLogger(__name__)


class SMTPMailingProvider(MailingProvider):
    def __init__(self):
        self.smtp_host = None
        self.smtp_port = 587
        self.username = None
        self.password = None
        self.use_tls = True
        self.timeout = 30  # segundos

    def set_credentials(self, credentials: Dict[str, str]):
        self.smtp_host = credentials.get("host")
        self.smtp_port = int(credentials.get("port", 587))
        self.username = credentials.get("username")
        self.password = credentials.get("password")
        if "tls" in credentials:
            self.use_tls = str(credentials.get("tls", "true")).lower() == "true"

        # DEBUG: mostrar lo que llega
        print("SMTP Credentials loaded:")
        print(f"  host={self.smtp_host}")
        print(f"  port={self.smtp_port}")
        print(f"  username={self.username!r}")
        print(f"  password={'***' if self.password else None}")
        print(f"  use_tls={self.use_tls}")
        print(credentials)

    def _build_message(self, envio: MailEnvio, render_subject:str, render_body:str, adjuntos: List[str] | None) -> Tuple[EmailMessage, List[str]]:
        if not envio.de:
            raise ValueError("Campo 'de' (From) obligatorio no informado")
        if not envio.para:
            raise ValueError("Campo 'para' (To) obligatorio no informado")

        msg = EmailMessage()
        msg["Subject"] = render_subject or ""
        msg["From"] = envio.de
        msg["To"] = envio.para

        if envio.cc:
            msg["Cc"] = envio.cc
        # No dejar Bcc en el header para no exponerlo
        if envio.bcc:
            msg["Bcc"] = envio.bcc

        if envio.reply_to:
            msg["Reply-To"] = envio.reply_to
        if envio.clave_externa:
            msg["X-Clave-Externa"] = envio.clave_externa

        # Prioridad
        if envio.prioridad == 1:
            msg["X-Priority"] = "1"
            msg["Priority"] = "urgent"
            msg["Importance"] = "high"

        # Cuerpo
        if self._looks_like_html(render_body):
            msg.set_content("Este correo requiere un visor HTML.")
            msg.add_alternative(render_body or "", subtype="html")
        else:
            msg.set_content(render_body or "")

        # Adjuntos
        for path in adjuntos or []:
            if not os.path.isfile(path):
                logger.warning(f"Adjunto no encontrado, se omite: {path}")
                continue

            ctype, _ = mimetypes.guess_type(path)
            ctype = ctype or "application/octet-stream"
            maintype, subtype = ctype.split("/", 1)

            basename = os.path.basename(path)

            # Formato especial para inline: cid__<cid>__nombre.png
            cid = None
            filename = basename
            if basename.startswith("cid__"):
                parts = basename.split("__", 2)
                if len(parts) == 3:
                    _, cid, filename = parts

            with open(path, "rb") as f:
                data = f.read()

            if cid:
                # Imagen inline con Content-ID
                msg.add_attachment(
                    data,
                    maintype=maintype,
                    subtype=subtype,
                    filename=filename,
                    disposition="inline",
                    cid=cid,
                )
            else:
                # Adjunto normal
                msg.add_attachment(
                    data,
                    maintype=maintype,
                    subtype=subtype,
                    filename=filename,
                )

        # Construir envelope recipients (To + Cc + Bcc)
        recipients = []
        for header in ("To", "Cc", "Bcc"):
            if header in msg:
                recipients.extend([addr.strip() for addr in str(msg[header]).split(",") if addr.strip()])

        # Quitar Bcc del header para no exponerlo
        if "Bcc" in msg:
            del msg["Bcc"]

        return msg, recipients

    def send_mail(self, envio: MailEnvio, render_subject: str, render_body: str, adjuntos: List[str]) -> Dict[str, object]:
        """
        Envía el correo. Lanza excepción si hay fallo.
        Devuelve un dict con info de diagnóstico:
          {
            "failed_recipients": dict devuelto por smtplib (vacío si todo ok),
            "server_host": str,
            "server_port": int,
            "used_tls": bool,
            "logged_in_as": str|None
          }
        """
        if not self.smtp_host:
            raise ValueError("Host SMTP no configurado")
        if not self.smtp_port:
            raise ValueError("Puerto SMTP no configurado")

        msg, recipients = self._build_message(envio, render_subject, render_body, adjuntos)

        logger.info(
            f"SMTP: conectando a {self.smtp_host}:{self.smtp_port} | TLS={self.use_tls} | "
            f"user={'<none>' if not self.username else self.username}"
        )

        try:
            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=self.timeout) as server:
                server.set_debuglevel(1)

                # EHLO implícito en send/feature calls, pero forzamos para registrar capacidades
                code, resp = server.ehlo()
                logger.debug(f"EHLO -> {code} {resp!r}")

                if self.use_tls:
                    logger.debug("Iniciando STARTTLS...")
                    code, resp = server.starttls()
                    logger.debug(f"STARTTLS -> {code} {resp!r}")
                    # EHLO tras TLS (recomendado)
                    code, resp = server.ehlo()
                    logger.debug(f"EHLO (post-TLS) -> {code} {resp!r}")

                if self.username:
                    logger.debug(f"Login SMTP como {self.username}...")
                    server.login(self.username, self.password or "")

                if not recipients:
                    raise ValueError("No hay destinatarios (To/Cc/Bcc) para el envío")

                logger.info(f"Enviando mensaje a {', '.join(recipients)}; asunto='{msg['Subject']}'")
                failed = server.send_message(msg, from_addr=msg["From"], to_addrs=recipients)
                # Nota: send_message devuelve dict de errores: vacío == éxito
                logger.debug(f"Resultado send_message (failed_recipients): {failed}")

                # Comprobación explícita
                if failed:
                    raise smtplib.SMTPException(f"Fallo parcial de entrega: {failed}")

                # NOOP para verificar que la conexión sigue viva (opcional)
                try:
                    code, resp = server.noop()
                    logger.debug(f"NOOP -> {code} {resp!r}")
                except smtplib.SMTPException:
                    # No crítico después de enviar
                    pass

                return {
                    "failed_recipients": failed,
                    "server_host": self.smtp_host,
                    "server_port": self.smtp_port,
                    "used_tls": self.use_tls,
                    "logged_in_as": self.username,
                }

        except (smtplib.SMTPAuthenticationError) as e:
            # Error de autenticación: propagar con mensaje claro
            logger.error(f"Error de autenticación SMTP: {e}", exc_info=True)
            raise
        except (smtplib.SMTPConnectError, smtplib.SMTPServerDisconnected) as e:
            logger.error(f"Error de conexión SMTP: {e}", exc_info=True)
            raise
        except smtplib.SMTPRecipientsRefused as e:
            logger.error(f"Destinatarios rechazados: {e.recipients}", exc_info=True)
            raise
        except smtplib.SMTPDataError as e:
            logger.error(f"SMTP DATA error {getattr(e, 'smtp_code', '?')}: {getattr(e, 'smtp_error', e)}", exc_info=True)
            raise
        except smtplib.SMTPException as e:
            logger.error(f"Error SMTP genérico: {e}", exc_info=True)
            raise
        except Exception as e:
            logger.error(f"Error no-SMTP en envío: {e}", exc_info=True)
            raise
