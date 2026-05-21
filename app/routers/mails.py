from fastapi import APIRouter, Request, HTTPException, UploadFile, File, Form, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from pathlib import Path
import os
import datetime
import shutil
from app.utils.dates import ahora
from app.config.db import get_db_manager
from app.models.mail.mail_app_servidores import MailAppServidor
from app.services.mails import MailsService
from app.models.mail.mail_servidores import MailServidor

from app.config.db import get_db
from app.schemas.mails import SendMailResponse

from sqlmodel import Session
from dotenv import load_dotenv

load_dotenv()

router = APIRouter(prefix="/bo/mail", tags=["mail"])


@router.post(
    "/send",
    response_model=SendMailResponse,
    summary="Enviar correo electrónico",
    description="Envía un correo electrónico con soporte para adjuntos, plantillas y programación de envío.",
)
async def send_mail_handler(
    request: Request,
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
    files: Optional[List[UploadFile]] = File(None),
    db: Session = Depends(get_db),
) -> SendMailResponse:
    id_app = int(os.getenv("APP_ID"))
    # Verificar o recuperar el servidor
    if id_servidor:
        stmt = select(MailAppServidor.id_servidor).where(
            MailAppServidor.id_app == id_app,
            MailAppServidor.id_servidor == id_servidor,
            MailAppServidor.activo == "S",
        )
        result = db.execute(stmt)
        valid_id = result.scalar_one_or_none()
        if not valid_id:
            raise HTTPException(
                status_code=404, detail="Servidor no encontrado para esta app"
            )
    else:
        stmt = (
            select(MailAppServidor.id_servidor)
            .where(MailAppServidor.id_app == id_app, MailAppServidor.activo == "S")
            .order_by(MailAppServidor.orden_servidor)
        )
        result = db.execute(stmt)
        id_servidor = result.scalar_one_or_none()
        if not id_servidor:
            raise HTTPException(
                status_code=404, detail="Servidor no encontrado para esta app"
            )

    # Procesar adjuntos
    adjuntos = []
    if files:
        media_root = Path(os.getenv("MAIL_MEDIA_PATH", "app/media/mail"))
        timestamp = ahora().strftime("%Y%m%d%H%M%S")  # Cambio fecha aqui
        os.makedirs(media_root, exist_ok=True)

        for file in files:
            safe_name = f"{timestamp}_{file.filename}"
            save_path = media_root / safe_name
            with open(save_path, "wb") as f:
                shutil.copyfileobj(file.file, f)
            adjuntos.append(
                {
                    "url": str(save_path),
                    "nombre": file.filename,
                    "mime_type": file.content_type,
                    "extension": Path(file.filename).suffix,
                }
            )

    # Justo antes de llamar al servicio de envío:
    # Obtener valores por defecto si faltan
    stmt = select(MailServidor).where(MailServidor.id == id_servidor)
    result = db.execute(stmt)
    mail_server = result.scalar_one_or_none()

    if not mail_server:
        raise HTTPException(status_code=404, detail="Servidor no encontrado")

    # Si no se proporcionan estos campos, tomar los del servidor
    if not de:
        de = mail_server.de
    if not de_nombre:
        de_nombre = mail_server.de_nombre
    if not reply_to:
        reply_to = mail_server.reply_to

    print(" ADJUNTOS 1 ==>> ", adjuntos)

    # Llamada al servicio
    mail_service = MailsService()
    envio_id = await mail_service.send_mail(
        db=db,
        id_app=id_app,
        user=user,
        id_servidor=None,
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
