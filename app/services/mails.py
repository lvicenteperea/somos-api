from typing import Optional, List, Dict, Any
from sqlmodel import select
from fastapi import HTTPException, status
from app.models.mail.mail_envios import MailEnvio
from app.models.mail.mail_robinson import MailRobinson
from app.mailing.mailing_handler import MailingHandler
from app.models.somos_configuracion import SomosConfiguracion
import logging
from datetime import datetime
import re
import psutil
import subprocess
from app.utils.dates import ahora
import os
from pathlib import Path
from sqlmodel import Session
from sqlalchemy import text
from app.utils.call_db_procedure import call_db_procedure, call_db_procedure_json
from app.repositories.tarjetas_repository import TarjetasRepository
import sys
import json
from dotenv import load_dotenv
import asyncio

logger = logging.getLogger(__name__)

load_dotenv()


class MailsService:
    """
    Servicio para gestión de envíos de correos electrónicos.
    """

    async def send_mail(
        self,
        db: Session,
        id_app: int,
        user: str,
        id_servidor: Optional[int],
        id_participante: int,
        para: str,
        para_nombre: Optional[str],
        de: Optional[str],
        de_nombre: Optional[str],
        cc: Optional[str],
        bcc: Optional[str],
        prioridad: Optional[int],
        reply_to: Optional[str],
        clave_externa: Optional[str],
        asunto: str,
        cuerpo: str,
        lenguaje: Optional[str],
        parametros: Optional[str],
        fecha_envio: Optional[str],
        identificador_externo: Optional[str],
        adjuntos: Optional[List[dict]] = None,
        send_now: bool = False,
    ) -> int:
        """
        Guarda un email y, si send_now es True, lo envía inmediatamente.
        """

        try:
            resultado_proc = await call_db_procedure(
                db=db,
                procedure_name="w_mail_graba_mail",
                ordered_params=[
                    ("v_idApp", id_app),
                    ("v_user", user),
                    ("v_retNum", 0),
                    ("v_retTxt", ""),
                    ("v_id_servidor", id_servidor),
                    ("v_id_participante", id_participante),
                    ("v_para", para),
                    ("v_para_nombre", para_nombre),
                    ("v_de", de),
                    ("v_de_nombre", de_nombre),
                    ("v_cc", cc),
                    ("v_bcc", bcc),
                    ("v_prioridad", prioridad),
                    ("v_reply_to", reply_to),
                    ("v_clave_externa", clave_externa),
                    ("v_asunto", asunto),
                    ("v_cuerpo", cuerpo),
                    ("v_lenguaje", lenguaje or "es"),
                    ("v_parametros", parametros),
                    ("v_fecha_envio", fecha_envio),
                    ("v_id_externo", identificador_externo),
                    (
                        "v_adjuntos",
                        json.dumps(adjuntos or [], ensure_ascii=False),
                    ),  # JSON.stringify
                    ("v_ID", 0),
                ],
                output_vars=["v_retNum", "v_retTxt", "v_ID"],
            )

            envio_id = resultado_proc["v_ID"]
            if send_now:
                # Envío inmediato: intentar y actualizar a OK/Error
                await self.send_mail_process(db, envio_id)

            # self.start_daemon()

            return envio_id

        except Exception as e:
            logger.error(f"Error al preparar envío de mail: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error al enviar mail: {str(e)}",
            )

    async def send_mail_process(self, db: Session, envio_id: int):
        """
        Ejecuta el envío real de un mail ya registrado.
        """
        envio: MailEnvio | None = None
        try:
            stmt = select(MailEnvio).where(MailEnvio.id == envio_id)
            result = db.execute(stmt)
            envio = result.scalar_one_or_none()

            if not envio:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"No se encontró el envío con ID {envio_id}",
                )

            rob, r_mail = MailsService.check_robinson(envio, db)
            if rob:
                envio.estado = "L"  # Lista Robinson
                envio.error = f"Email bloqueado por lista Robinson: {r_mail}"
                envio.updated_at = ahora()  # Cambio fecha aqui
                db.add(envio)
                db.commit()
                return

            handler = MailingHandler(envio.id_servidor, db)
            diag = handler.send_mail(envio)  # Lanza excepción si falla

            envio.estado = "O"  # OK
            envio.fecha_enviado = ahora()  # Cambio fecha aqui
            envio.error = None  # limpiar error previo si lo hubiera
            logger.info(
                f"Email ID {envio.id} enviado OK a {envio.para}. "
                f"SMTP {diag.get('server_host')}:{diag.get('server_port')} TLS={diag.get('used_tls')} "
                f"user={diag.get('logged_in_as') or '<none>'}"
            )

        except Exception as e:
            logger.exception(f"Error en el envío del email con ID {envio_id}")
            # Si 'envio' no existe (caso 404), re-lanzamos la excepción HTTP
            if isinstance(e, HTTPException):
                raise
            # Si hay objeto 'envio', marcamos estado de error y guardamos mensaje
            if envio is not None:
                detalle_prev = (envio.error or "").strip()
                nuevo_detalle = str(e).strip()
                envio.estado = "E"
                envio.error = (
                    detalle_prev + ("\n" if detalle_prev else "") + nuevo_detalle
                )[
                    :2000
                ]  # evitar overflow
            else:
                # No hay registro que actualizar; re-lanzar para que el caller maneje
                raise
        finally:
            if envio is not None:
                envio.updated_at = ahora()  # Cambio fecha aqui
                db.add(envio)
                db.commit()

    @staticmethod
    def check_robinson(envio: MailEnvio, db: Session) -> (bool, str):
        """
        Verifica si alguno de los destinatarios está en la lista Robinson.
        Retorna True si hay algún match, False en caso contrario.
        """

        def extract_emails(campo: Optional[str]) -> list[str]:
            if not campo:
                return []
            return [
                email.strip().lower()
                for email in re.split(r"[;,]", campo)
                if email.strip()
            ]

        emails = list(
            set(
                extract_emails(envio.para)
                + extract_emails(envio.cc)
                + extract_emails(envio.bcc)
            )
        )

        if os.getenv("DEVELOPMENT", "0") == "1":
            for e in emails:
                if not (
                    e.endswith("somos.es")
                    or e.endswith("solvium.es")
                    or e == "lvicenteperea@gmail.com"
                    or e == "sergio.torio@gmail.com"
                    or e == "davidpedro.chico@gmail.com"
                    or e == "whatsapp.9mpxqg@zapiermail.com"
                    or e.endswith("hangarxxi.com")
                    or e.endswith(".mail-tester.com")
                    or e.endswith("arkisen.com")
                    or e.endswith("sawabonacreative.com")
                    or e.endswith("yopmail.com")
                ):
                    return True, e  # ← aquí decides cómo señalas el bloqueo

        if not emails:
            return False, ""

        stmt = select(MailRobinson).where(
            MailRobinson.id_app == envio.id_app,
            MailRobinson.email.in_(emails),
            MailRobinson.nivel.in_(["T", envio.estado]),
        )

        result = db.execute(stmt)
        if result.first() is not None:
            return True, result.first().email
        return False, ""

    @staticmethod
    def _render_notification_body(mensaje: str, data: Optional[Dict[str, Any]]) -> str:
        """
        Construye el cuerpo del mail combinando el mensaje en texto
        y una representación legible del dict `data`.
        """
        if not data:
            return mensaje
        try:
            pretty = json.dumps(data, ensure_ascii=False, indent=2)
        except Exception:
            # fallback por si algo no es serializable
            pretty = str(data)
        return f"{mensaje}\n\n---\nDatos:\n{pretty}"

    @staticmethod
    def send_notification_email_no_wait(
        db: Session, mensaje: str, asunto: str, data: Optional[Dict[str, Any]] = None
    ):
        asyncio.create_task(
            MailsService.send_notification_email(db, mensaje, asunto, data)
        )

    @staticmethod
    async def send_notification_email(
        db: Session,
        mensaje: str,  # aquí llega ya el cuerpo renderizado si se llama desde *_no_wait
        asunto: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> int:
        """
        Envía un email de notificación a la lista configurada para alertas.
        - id_app: de APP_ID (env)
        - destinatarios: SomosConfiguracion('alertas','Error_reservas') o NOTIFY_EMAILS
        Devuelve el ID del envío registrado o -1 si algo falla/está incompleto.
        """
        mensaje = MailsService._render_notification_body(mensaje, data)

        try:
            # 1) id_app
            try:
                id_app = int(os.getenv("APP_ID"))
            except Exception:
                return -1

            # 3) destinatarios
            para = SomosConfiguracion.get_value(
                db, id_app, "alertas", "Error_reservas", os.getenv("NOTIFY_EMAILS", "")
            )
            if not para or para == "":
                return -1

            # 4) enviar
            servicio = MailsService()
            envio_id = await servicio.send_mail(
                db=db,
                id_app=id_app,
                user="system",
                id_servidor=None,
                id_participante=0,
                para=para,
                para_nombre=None,
                de=None,
                de_nombre=None,
                cc=None,
                bcc=None,
                prioridad=1,
                reply_to=None,
                clave_externa=None,
                asunto=asunto,
                cuerpo=mensaje,  # ← mensaje ya puede incluir el render del dict
                lenguaje="es",
                parametros=None,
                fecha_envio=None,
                identificador_externo="notification",
                adjuntos=None,
                send_now=True,
            )
            return envio_id

        except Exception as e:
            logger.exception(f"Error en send_notification_email: {asunto} - {mensaje}")
            logger.exception(e)
            return -1

    @staticmethod
    async def notify_expiring_cards(db: Session) -> Dict[str, Any]:
        """
        Consulta las tarjetas de clientes activos que caducan en los próximos
        30 días e invoca w_mail_graba_mail por cada una para encolar el email
        de recordatorio de caducidad.

        Retorna un dict con el número de emails encolados y de errores.
        """
        try:
            id_app = int(os.getenv("APP_ID"))
        except Exception:
            logger.error("notify_expiring_cards: APP_ID no configurado")
            return {"enviados": 0, "errores": 0}

        try:
            repo = TarjetasRepository(db)
            tarjetas = repo.get_tarjetas_proximas_a_caducar()
        except Exception as e:
            logger.error(f"notify_expiring_cards: error al consultar tarjetas: {e}")
            return {"enviados": 0, "errores": 1}

        if not tarjetas:
            logger.info("notify_expiring_cards: no hay tarjetas próximas a caducar")
            return {"enviados": 0, "errores": 0}

        logger.info(f"notify_expiring_cards: {len(tarjetas)} tarjeta(s) encontradas")

        enviados = 0
        errores = 0
        for row in tarjetas:
            id_cliente: int = row.id_cliente
            email: str = row.email
            nombre = row.nombre
            apellido1 = row.apellido1
            apellido2 = row.apellido2
            alias = row.alias
            card_expire_date = row.card_expire_date

            if not email:
                logger.warning(
                    f"notify_expiring_cards: cliente {id_cliente} sin email, se omite"
                )
                errores += 1
                continue

            nombre_completo = " ".join(
                p for p in [nombre, apellido1, apellido2] if p
            ).strip()

            fecha_str = (
                card_expire_date.strftime("%d/%m/%Y")
                if hasattr(card_expire_date, "strftime")
                else str(card_expire_date)
            )

            parametros = json.dumps(
                {
                    "NOMBRE": nombre,
                    "APELLIDO1": apellido1,
                    "APELLIDO2": apellido2,
                    "NOMBRE_COMPLETO": nombre_completo,
                    "ALIAS": alias,
                    "CARD_EXPIRE_DATE": fecha_str,
                },
                ensure_ascii=False,
            )

            clave_externa = f"alarma_tj_cad-{id_cliente}"

            try:
                await call_db_procedure_json(
                    db=db,
                    procedure_name="w_mail_graba_mail_slug",
                    ordered_params=[
                        ("v_idApp", id_app),
                        ("v_user", "admin"),
                        ("v_retNum", 0),
                        ("v_retTxt", ""),
                        ("v_slug", "EMAIL_CAD_TARJ"),
                        ("v_id_servidor", None),
                        ("v_id_participante", id_cliente),
                        ("v_para", email),
                        ("v_para_nombre", nombre_completo or None),
                        ("v_de", None),
                        ("v_de_nombre", None),
                        ("v_cc", None),
                        ("v_bcc", None),
                        ("v_prioridad", 5),
                        ("v_reply_to", None),
                        ("v_clave_externa", clave_externa),
                        ("v_lenguaje", "es"),
                        ("v_parametros", parametros),
                        ("v_fecha_envio", None),
                        ("v_id_externo", "card_expiry"),
                        ("v_adjuntos", json.dumps([], ensure_ascii=False)),
                        ("v_id_email", 0),
                    ],
                    output_vars=["v_retNum", "v_retTxt", "v_id_email"],
                )
                logger.info(
                    f"notify_expiring_cards: email encolado → {email} "
                    f"(tarjeta '{alias}', caduca {fecha_str})"
                )
                enviados += 1
            except Exception as e:
                logger.error(
                    f"notify_expiring_cards: error al encolar email para "
                    f"{email} (tarjeta '{alias}'): {e}"
                )
                errores += 1

        logger.info(
            f"notify_expiring_cards: finalizado — {enviados} enviados, {errores} errores"
        )
        return {"enviados": enviados, "errores": errores}
