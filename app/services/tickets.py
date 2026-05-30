from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Dict
from uuid import uuid4
from zoneinfo import ZoneInfo

from fastapi import HTTPException, UploadFile, status
from sqlmodel import Session

from app.config.settings import settings
from app.schemas.tickets import TicketValidaResponse
from app.utils.call_db_procedure import call_db_procedure_no_exception
from app.utils.dates import ahora


class TicketsService:
    """Servicio para validacion de tickets."""

    ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".pdf"}

    async def validar_ticket(
        self,
        db: Session,
        id_app: int,
        user: str,
        imagen: UploadFile,
        id_campana: int,
        numero_ticket: str,
        fecha_ticket: datetime,
        importe: Decimal,
    ) -> TicketValidaResponse:
        

        # try:
            imagen_guardada = await self._save_ticket_image(imagen)

            fecha_madrid = self._format_madrid_datetime(fecha_ticket)

            resultado_proc = await call_db_procedure_no_exception(
                db=db,
                procedure_name="w_ticket_valida",
                ordered_params=[
                    ("v_idApp", id_app),
                    ("v_user", user),
                    ("v_retNum", 0),
                    ("v_retTxt", ""),
                    ("v_id_campana", id_campana),
                    ("v_ticket", imagen_guardada["url"]),
                    ("v_numero_ticket", numero_ticket),
                    ("v_fecha", fecha_madrid),
                    ("v_importe", float(importe)),
                    ("v_cupon", None),
                    ("v_id", None),
                ],
                output_vars=["v_retNum", "v_retTxt", "v_cupon", "v_id"],
            )

            ret_num = self._to_int(resultado_proc.get("v_retNum"), default=-99)
            ret_txt = resultado_proc.get("v_retTxt") or ""

            if ret_num == -99:
                raise HTTPException(
                    status_code=status.HTTP_406_NOT_ACCEPTABLE,
                    detail=ret_txt,
                )

            if ret_num < 0:
                raise HTTPException(
                    status_code=status.HTTP_410_GONE,
                    detail=ret_txt,
                )

            id_cupon = resultado_proc.get("v_id")
            if id_cupon == "":
                id_cupon = None

            return TicketValidaResponse(
                texto=ret_txt,
                cupon=resultado_proc.get("v_cupon"),
                id_cupon=id_cupon,
            )
        # except HTTPException:
        #     raise
        # except Exception as exc:
        #     raise HTTPException(
        #         status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        #         detail=f"Error al validar el ticket: {exc}",
        #     )
        
    # -----------------------------------------------------------------------------------
    async def _save_ticket_image(self, imagen: UploadFile) -> Dict[str, str]:
        original_name = Path(imagen.filename or "ticket").name
        extension = Path(original_name).suffix.lower()


        print("Datos imagen:", original_name, extension, imagen.content_type)


        if extension not in self.ALLOWED_IMAGE_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"La imagen debe ser {self.ALLOWED_IMAGE_EXTENSIONS}",
            )

        if imagen.content_type and not imagen.content_type.lower().startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El fichero debe ser una imagen",
            )

        media_root = Path(settings.TICKET_MEDIA_PATH)
        media_root.mkdir(parents=True, exist_ok=True)

        timestamp = ahora().strftime("%Y%m%d%H%M%S")
        safe_name = f"{timestamp}_{uuid4().hex}{extension}"
        save_path = media_root / safe_name
        max_bytes = settings.TICKET_MAX_IMAGE_MB * 1024 * 1024
        total_bytes = 0

        try:
            with open(save_path, "wb") as output_file:
                while chunk := await imagen.read(1024 * 1024):
                    total_bytes += len(chunk)
                    if total_bytes > max_bytes:
                        raise HTTPException(
                            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            detail=(
                                "La imagen supera el tamano maximo de "
                                f"{settings.TICKET_MAX_IMAGE_MB} MB"
                            ),
                        )
                    output_file.write(chunk)
        except HTTPException:
            save_path.unlink(missing_ok=True)
            raise
        except Exception as exc:
            save_path.unlink(missing_ok=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error al guardar la imagen del ticket: {exc}",
            )

        if total_bytes == 0:
            save_path.unlink(missing_ok=True)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La imagen no puede estar vacia",
            )

        return {
            "url": save_path.as_posix(),
            "nombre": safe_name,
            "nombre_original": original_name,
        }

    @staticmethod
    def _format_madrid_datetime(value: datetime) -> str:
        madrid_tz = ZoneInfo(settings.TIMEZONE)
        if value.tzinfo is None:
            madrid_value = value.replace(tzinfo=madrid_tz)
        else:
            madrid_value = value.astimezone(madrid_tz)

        return madrid_value.replace(tzinfo=None).strftime("%Y-%m-%d %H:%M:%S")

    @staticmethod
    def _to_int(value, default: int) -> int:
        try:
            return int(value)
        except (TypeError, ValueError):
            return default
