from typing import Optional, Type, Dict
import logging
from sqlmodel import select, Session
from typing import Dict, List, Tuple, Any
import json, re, os, io

from app.config.settings import settings
from app.models.mail.mail_servidores import MailServidor
from app.models.mail.mail_envios import MailEnvio
from app.models.mail.mail_adjuntos import MailAdjunto
from app.mailing.providers.mailing_provider import MailingProvider
from app.mailing.providers.smtp_mailing_provider import SMTPMailingProvider
from app.mailing.providers.sendgrid_mailing_provider import SendgridMailingProvider

import qrcode
from qrcode.constants import ERROR_CORRECT_M

import hashlib
import tempfile

# Si tienes el provider de SendGrid, descomenta la siguiente línea:
# from app.mailing.providers.sendgrid_mailing_provider import SendgridMailingProvider

logger = logging.getLogger(__name__)

# Registro de providers disponibles (clave en minúsculas)
PROVIDERS: Dict[str, Type[MailingProvider]] = {
    "smtp": SMTPMailingProvider,
    "sendgrid": SendgridMailingProvider,
}

_PARAM_PATTERN = re.compile(r"{{\s*([a-zA-Z0-9_.-]+)\s*}}")

class MailingHandler:
    def __init__(
        self,
        id_servidor: int,
        db: Session
    ):
        self.id_servidor = id_servidor
        self.db = db
        self.provider: Optional[MailingProvider] = None
        self._init_provider()

    def _init_provider(self):
        stmt = select(MailServidor).where(MailServidor.id == self.id_servidor)
        result = self.db.exec(stmt).first()

        if not result:
            raise ValueError(f"No se encontró el servidor con ID {self.id_servidor}")

        creds = result.credentials_dict
        servicio = (result.nombre_clase or "").strip().lower()

        provider_cls = PROVIDERS.get(servicio)
        if provider_cls is None:
            disponibles = ", ".join(sorted(PROVIDERS.keys())) or "<ninguno>"
            raise NotImplementedError(
                f"Proveedor no soportado: {servicio!r}. Disponibles: {disponibles}"
            )

        self.provider = provider_cls()
        self.provider.set_credentials(creds)

    def _render_subject_with_params(self, envio: "MailEnvio") -> str:
        """
        Sustituye {{clave}} en envio.cuerpo con valores de envio.parametros.
        Soporta un placeholder especial: {{qr_html_image}}
        - Toma el valor de envio.parametros['qr_html_image']
        - Genera un PNG QR embebido como <img src="data:image/png;base64,...">
        """
        mapping = {}
        if envio.parametros:
            try:
                mapping = json.loads(envio.parametros)
            except Exception:
                mapping = {}

        def _repl(m: re.Match) -> str:
            k = m.group(1)

            # Sustitución normal por parámetros
            return str(mapping.get(k, m.group(0)))

        return _PARAM_PATTERN.sub(_repl, envio.asunto or "")

    def _qr_cid(self, payload: str) -> str:
        """
        Genera un CID determinista a partir del payload.
        Así _render_body_with_params y _collect_attachment_paths
        pueden usar el mismo cid sin compartir estado.
        """
        h = hashlib.sha1(payload.encode("utf-8")).hexdigest()
        return f"qr_{h}"

    def _create_qr_file(self, payload: str, cid: str) -> str:
        """
        Genera el PNG del QR en disco y devuelve la ruta del fichero.
        El nombre del fichero codifica el cid para que el provider
        pueda interpretar que es inline.

        Formato: cid__<cid>__qrcode.png
        """
        qr = qrcode.QRCode(
            version=None,
            error_correction=ERROR_CORRECT_M,
            box_size=8,
            border=2,
        )
        qr.add_data(payload)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        data = buf.getvalue()

        base_dir = os.path.join(tempfile.gettempdir(), "somos_qr")
        os.makedirs(base_dir, exist_ok=True)

        filename = f"cid__{cid}__qrcode.png"
        path = os.path.join(base_dir, filename)

        with open(path, "wb") as f:
            f.write(data)

        return path

    def _render_body_with_params(self, envio: "MailEnvio") -> str:
        """
        Sustituye {{clave}} en envio.cuerpo con valores de envio.parametros.
        Soporta un placeholder especial: {{qr_html_image}}
        - Toma el valor de envio.parametros['qr_html_image']
        - Genera un <img src="cid:..."> que apunta a un adjunto inline.
        """
        mapping = {}
        if envio.parametros:
            try:
                mapping = json.loads(envio.parametros)
            except Exception:
                mapping = {}

        def _repl(m: re.Match) -> str:
            k = m.group(1)

            if k == "qr_html_image":
                payload = mapping.get("qr_html_image")
                if not payload:
                    return m.group(0)
                try:
                    cid = self._qr_cid(str(payload))
                    return f'<img src="cid:{cid}" alt="QR" class="qr-code-image"/>'
                except Exception:
                    return m.group(0)

            elif k == "url":
                return settings.URL_PWA

            return str(mapping.get(k, m.group(0)))

        return _PARAM_PATTERN.sub(_repl, envio.cuerpo or "")

    def _collect_attachment_paths(self, envio: MailEnvio) -> List[str]:
        """
        Devuelve las rutas (url) de todos los adjuntos asociados a este envío,
        consultando mail_adjuntos por id_envio. Orden estable por id.
        - Si la url es local (no http/https), se normaliza.
        - Si es local y el fichero no existe, se avisa y se omite.
        Además:
        - Si envio.parametros incluye 'qr_html_image', genera un PNG de QR
          en disco y lo añade como adjunto con nombre codificado para inline.
        """
        paths: List[str] = []

        # 1) adjuntos existentes en mail_adjuntos
        if not envio.id:
            logger.warning("MailEnvio sin id; no se pueden consultar adjuntos.")
        else:
            stmt = (
                select(MailAdjunto)
                .where(MailAdjunto.id_envio == envio.id)
                .order_by(MailAdjunto.id)
            )
            adjuntos = self.db.exec(stmt).all()

            for a in adjuntos:
                if not a or not a.url:
                    continue
                url = a.url

                is_remote = "://" in url
                if not is_remote:
                    url_norm = os.path.normpath(url)
                    if not os.path.isfile(url_norm):
                        logger.warning("Adjunto no encontrado en disco, se omite: %s", url_norm)
                        continue
                    paths.append(url_norm)
                else:
                    paths.append(url)

        # 2) adjunto QR inline si procede
        mapping = {}
        if envio.parametros:
            try:
                mapping = json.loads(envio.parametros)
            except Exception:
                mapping = {}

        payload = mapping.get("qr_html_image")
        if payload:
            try:
                cid = self._qr_cid(str(payload))
                qr_path = self._create_qr_file(str(payload), cid)
                paths.append(qr_path)
            except Exception as e:
                logger.error("Error generando adjunto QR: %s", e, exc_info=True)

        return paths

    def send_mail(self, envio: MailEnvio):
        # TODO Verificar que si estamos en env->DEVELOPMENT no se manden emails
        if not self.provider:
            raise RuntimeError("Proveedor de mailing no inicializado")
        return self.provider.send_mail(
            envio,
            self._render_subject_with_params(envio),
            self._render_body_with_params(envio),
            self._collect_attachment_paths(envio)
        )
