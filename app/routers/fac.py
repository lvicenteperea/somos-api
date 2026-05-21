from fastapi import APIRouter, Request, HTTPException, UploadFile, File, Form, Depends
from fastapi.responses import JSONResponse
from typing import List, Optional
import os
from app.SAP.sap_billing_api import SapBillingApi
from sqlmodel import Session, SQLModel, select

from app.config.db import get_db

from sqlmodel import Session
from dotenv import load_dotenv
from app.models.fac.FacCabecera import FacCabecera, FacturaEstado

from app.utils.call_db_procedure import CoreDatabaseException

load_dotenv()

router = APIRouter(prefix="/bo/fac", tags=["mail"])


@router.get("/base64pdf/{fac_id}")
async def send_mail_handler(
    request: Request,
    fac_id: int,
    db: Session = Depends(get_db)
):
    id_app = int(os.getenv("APP_ID"))
    api = SapBillingApi()

    factura = db.exec(
        select(FacCabecera).where(FacCabecera.id == fac_id)
    ).one()

    if not factura or not factura.estado == FacturaEstado.ENVIADA:
        raise HTTPException(status_code=404, detail="Factura no encontrada")

    try:
        if factura.base_imponible > 0:
            resp = await api.print_invoice(str(factura.sap_BaseEntry), factura.sap_Company)
            print("Pint Invoice Response")
            print(resp)
        else:
            resp = await api.print_credit_note(str(factura.sap_BaseEntry), factura.sap_Company)
            print("Pint Credit Note Response")
            print(resp)


    except Exception as e:
        raise CoreDatabaseException(
            status_code=500,
            slug="",
            log=e,
            txt_cli="Hubo un error generando la factura")

    if isinstance(resp, dict) and resp.get("base64PDF"):
        return JSONResponse({"status": "ok", "base64pdf": resp.get("base64PDF")})
    else:
        raise CoreDatabaseException(
            status_code=500,
            slug="",
            log=f"Hubo un error contactando con SAP. Respuesta recibida: {resp}",
            txt_cli="Hubo un error generando la factura")



