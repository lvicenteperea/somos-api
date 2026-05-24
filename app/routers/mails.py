import logging
import os
import shutil
from pathlib import Path
from typing import List, Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlmodel import Session

from app.config.db import get_db
from app.config.settings import settings
from app.models.mail.mail_app_servidores import MailAppServidor
from app.models.mail.mail_servidores import MailServidor
from app.schemas.mails import SendMailResponse
from app.services.mails import MailsService
from app.utils.dates import ahora

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/bo/mail", tags=["mail"])


@router.post(
    "/send",
    response_model=SendMailResponse,
    summary="Enviar correo electronico",
    description="Envia un correo electronico con adjuntos opcionales y programacion de envio.",
)
async def send_mail_handler(
    user: str = Form(...),
    id_participante: Optional[int] = Form(0),
    para: str = Form(...),
    asunto: str = Form(...),
    cuerpo: str = Form(...),
    para_nombre: Optional[str] = Form(None),
    de: Optional[str] = Form(None),
    de_nombre: Optional[str] = Form(None),
    cc: Optional[str] = Form(None),
    bcc: Optional[str] = Form(None),
    prioridad: Optional[int] = Form(None),
    reply_to: Optional[str] = Form(None),
    clave_externa: Optional[str] = Form(None),
    lenguaje: Optional[str] = Form("es"),
    parametros: Optional[str] = Form(None),
    fecha_envio: Optional[str] = Form(None),
    identificador_externo: Optional[str] = Form(None),
    id_servidor: Optional[int] = Form(None),
    send_now: bool = Form(False),
    files: List[UploadFile] = File(default=[]),
    db: Session = Depends(get_db),
) -> SendMailResponse:
    id_app = settings.APP_ID
    id_servidor = _resolve_mail_server_id(db, id_app, id_servidor)
    mail_server = _get_mail_server(db, id_servidor)

    de = de or mail_server.de
    de_nombre = de_nombre or mail_server.de_nombre
    reply_to = reply_to or mail_server.reply_to

    adjuntos = _save_attachments(files)
    logger.debug("Adjuntos preparados para envio de mail: %s", len(adjuntos))

    envio_id = await MailsService().send_mail(
        db=db,
        id_app=id_app,
        user=user,
        id_servidor=id_servidor,
        id_participante=id_participante,
        para=para,
        para_nombre=para_nombre,
        de=de,
        de_nombre=de_nombre,
        cc=cc,
        bcc=bcc,
        prioridad=prioridad,
        reply_to=reply_to,
        clave_externa=clave_externa,
        asunto=asunto,
        cuerpo=cuerpo,
        lenguaje=lenguaje,
        parametros=parametros,
        fecha_envio=fecha_envio,
        identificador_externo=identificador_externo,
        adjuntos=adjuntos or None,
        send_now=send_now,
    )

    return JSONResponse({"status": "ok", "envio_id": envio_id})


def _resolve_mail_server_id(
    db: Session,
    id_app: int,
    id_servidor: Optional[int],
) -> int:
    if id_servidor:
        stmt = select(MailAppServidor.id_servidor).where(
            MailAppServidor.id_app == id_app,
            MailAppServidor.id_servidor == id_servidor,
            MailAppServidor.activo == "S",
        )
    else:
        stmt = (
            select(MailAppServidor.id_servidor)
            .where(MailAppServidor.id_app == id_app, MailAppServidor.activo == "S")
            .order_by(MailAppServidor.orden_servidor)
            .limit(1)
        )

    result = db.execute(stmt)
    resolved_id = result.scalar_one_or_none()
    if not resolved_id:
        raise HTTPException(
            status_code=404,
            detail="Servidor no encontrado para esta app",
        )
    return resolved_id


def _get_mail_server(db: Session, id_servidor: int) -> MailServidor:
    stmt = select(MailServidor).where(MailServidor.id == id_servidor)
    result = db.execute(stmt)
    mail_server = result.scalar_one_or_none()

    if not mail_server:
        raise HTTPException(status_code=404, detail="Servidor no encontrado")
    return mail_server


def _save_attachments(files: List[UploadFile]) -> List[dict]:
    if not files:
        return []

    media_root = Path(settings.MAIL_MEDIA_PATH)
    timestamp = ahora().strftime("%Y%m%d%H%M%S")
    os.makedirs(media_root, exist_ok=True)

    adjuntos = []
    for file in files:
        original_name = Path(file.filename or "attachment").name
        safe_name = f"{timestamp}_{uuid4().hex}_{original_name}"
        save_path = media_root / safe_name

        with open(save_path, "wb") as f:
            shutil.copyfileobj(file.file, f)

        adjuntos.append(
            {
                "url": str(save_path),
                "nombre": original_name,
                "mime_type": file.content_type,
                "extension": Path(original_name).suffix,
            }
        )

    return adjuntos
