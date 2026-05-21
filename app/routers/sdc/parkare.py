import traceback
import os
from fastapi import (
    APIRouter,
    Query,
    Depends,
    HTTPException,
    Depends,
    BackgroundTasks,
)
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import Optional
from app.config.db import get_db
from fastapi import status
from datetime import datetime
from dotenv import load_dotenv

from app.models.somos_configuracion import SomosConfiguracion
from app.services.rompetechos import RompetechosServiceRquest
import json
import logging
from app.schemas.parkare.schemas import (
    ParkarePassValidationRequest,
    ParkareTicketIssuedRequest,
    ParkareProductPassRequest,
)
from app.services.rotacion.parkare import ParkareBarrera, ParkareTransito

load_dotenv()

router = APIRouter(tags=["parkare"])

logger = logging.getLogger(__name__)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.get(
    "/precioDinamicoCajero",
    summary="Obtener precio dinámico del cajero",
    description="Calcula el precio dinámico de estacionamiento basado en el token de usuario y la fecha de salida prevista.",
)
async def precioDinamicoCajero(
    token: str = Query(..., description="Token de usuario"),
    id_aparcamiento: str = Query(
        ...,
        description="Identificador del aparcamiento, código de instalación que llega desde el SDC",
    ),
    matricula: str = Query(..., description="matricula del vehículo que quiere salir"),
    salida: str = Query(
        ..., description="Fecha de salida en formato YYYY-MM-DDTHH:MM:SS"
    ),
    fecha_cobro: Optional[str] = Query(
        None,
        description="formato YYYY-MM-DDTHH:MM:SS. Cuando el cliente ya ha pagado al menos una vez y se ha pasado del tiempo de cortesia, aquí debe ir la fecha en la que se hizo ese pago.",
    ),
    ticket: str = Query(None, description="Ticket de salida"),
    codigoPromocion: Optional[str] = Query(
        None,
        description="Codigo de promoción descuento o cualquier otro identificar que el cliente puede usar en la app de CluböT para obtener un descuento o una oferta comercial",
    ),
    db: Session = Depends(get_db),
):
    logger.warning(
        f"[DEBUG][llamada a precioDinamicoCajero parkare] : token:{token[:8]}... - aparcamiento:{id_aparcamiento} - salida:{salida} - matricula:{matricula} - ticket:{ticket} - codigoPromocion:{codigoPromocion}"
    )

    try:

        id_app = int(os.getenv("APP_ID"))
        servicio = RompetechosServiceRquest()

        result = await servicio.calculadora_cajero(
            db=db,
            id_app=id_app,
            user="usuario_dev",
            ret_code=0,
            ret_txt="OK",
            id_aparcamiento=id_aparcamiento,
            salida=salida,
            token=token,
            ticket=ticket,
            codigoPromocion=codigoPromocion,
        )

        if result.get("status") == "error":
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content=result,
            )

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=result,
        )

    except HTTPException as http_exc:
        raise http_exc

    except Exception as e:
        logger.error(f"[ERROR] Fallo en precioDinamicoCajero: {str(e)}")
        traceback.print_exc()

        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al calcular el precio dinámico",
                "detail": str(e),
            },
        )


# -------------------------------------------------------------------------------------------------
# Passvalidation para parkare
# -------------------------------------------------------------------------------------------------
@router.post(
    "/Passvalidation",
    summary="Pedir autorización de entrada, salida y cajero para un vehículo",
    description="Cuando un vehículo está entrando del parking, el sistema de control de acceso del parking llamará a este endpoint para solicitar la autorización de entrada, salida y pago en el cajero. ",
)
async def pass_validation(
    payload: ParkarePassValidationRequest,
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = None,
):
    try:
        barreras_service = ParkareBarrera()

        id_app = int(os.getenv("APP_ID"))
        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "parkare"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de parkare, revisar configuración",
                },
            )
        matricula = payload.LicensePlate or payload.SupportId or ""
        # Logica para definir tipo de entrada
        entrance_type = "vehicular"

        # Logica para definir flujo de PassValidation
        terminal_type = payload.TerminalType
        result = {}
        datos_soporte = {
            "matricula": matricula,
            "numeroSerieContactless": "",
            # Si el soporte es QR (SupportType=4) el SupportId es el código QR/barras
            "codigoBarras": payload.SupportId if payload.SupportType == 4 else "",
        }
        if terminal_type not in [1, 2, 6]:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "Tipo de terminal no soportado en PassValidation",
                },
            )
        validation_dt_iso = (
            payload.ValidationDateTime.isoformat()
            if payload.ValidationDateTime
            else datetime.now().isoformat()
        )
        parkare_data = {
            "license_plate": payload.LicensePlate,
            "license_plate_country_code": payload.LicensePlateCountryCode,
            "license_plate_confidence": payload.LicensePlateConfidence,
            "vehicle_type": payload.VehicleType,
            "identified_product_type": payload.IdentifiedProductType,
            "identified_product": payload.IdentifiedProduct,
            "product_type": payload.ProductType,
            "product_code": payload.ProductCode,
            "product_class": payload.ProductClass,
            "operations": payload.Operations,
            "support_type": payload.SupportType,
            "support_id": payload.SupportId,
            # Areas se convierte a dict para ser serializable como JSON
            "areas": [a.model_dump() for a in payload.Areas] if payload.Areas else [],
            "bank_card_brand_code": payload.BankCardBrandCode,
            "bank_card_brand_description": payload.BankCardBrandDescription,
            "payment_device_type": payload.PaymentDeviceType,
            "operator_id": payload.OperatorId,
            "subscription_id": payload.SubscriptionId,
            "parking_number": payload.ParkingNumber,
            "parking_alias": payload.ParkingAlias,
            "validation_number": payload.ValidationNumber,
            "validation_datetime": validation_dt_iso,
            "terminal_number": payload.TerminalNumber,
            "terminal_alias": payload.TerminalAlias,
        }
        if terminal_type == 1:
            # Entrada
            result = await barreras_service.autorizar_entrada(
                db=db,
                id_app=id_app,
                id_sdc=id_sdc,
                codigo_parking=payload.ParkingNumber,  # "1067"
                tipo_aparato="5",
                numero_aparato=payload.TerminalNumber,
                fecha_hora=payload.ValidationDateTime or datetime.now(),
                validation_number=payload.ValidationNumber,
                terminal_type=payload.TerminalType,
                datos_acceso=json.dumps(datos_soporte),
                license_plate=matricula,
                provider_name="parkare",
                entrance_type=entrance_type,
                background_tasks=background_tasks,
                sdc_extra_data=parkare_data,
            )
        elif terminal_type == 2:
            # Salida
            result = await barreras_service.autorizar_salida(
                db=db,
                id_app=id_app,
                id_sdc=id_sdc,
                codigo_parking=str(payload.ParkingNumber),
                tipo_aparato="6",
                numero_aparato=payload.TerminalNumber or 0,
                # En salida el ticket/producto viene en ProductCode
                ticket=payload.ProductCode or payload.SupportId or "",
                fecha_hora=payload.ValidationDateTime or datetime.now(),
                datos=json.dumps(datos_soporte),
                license_plate=matricula,
                provider_name="parkare",
                sdc_extra_data=parkare_data,
            )
        elif terminal_type == 6:
            # TODO: Agregar logica de cajero.
            pass

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
        raise http_exc

    except Exception as e:
        print("[ERROR] Fallo en autorizacion_usuario")
        print(str(e))
        traceback.print_exc()

        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al procesar autorización de entrada",
                "detail": str(e),
            },
        )


# -------------------------------------------------------------------------------------------------
# Tránsito de entrada: el SDC confirma que se ha emitido un ticket y el vehículo ha entrado
# -------------------------------------------------------------------------------------------------
@router.post(
    "/TicketIssued",
    summary="Notificación de emisión de ticket de entrada (tránsito de entrada)",
    description="El SDC notifica que se ha emitido un ticket de entrada y el vehículo ha pasado la barrera. "
    "Es equivalente al tránsito de entrada en otros SDCs. Solo es una notificación, no realiza autorización.",
)
async def ticket_issued(
    payload: ParkareTicketIssuedRequest,
    db: Session = Depends(get_db),
):
    logger.warning(
        f"[DEBUG][TicketIssued PARKARE] mat:{payload.LicensePlate} - ticket:{payload.TicketNumber} - parking:{payload.ParkingAlias}"
    )

    try:
        id_app = int(os.getenv("APP_ID"))
        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "parkare"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de parkare, revisar configuración",
                },
            )

        notificacion_data = {
            "parking_alias": payload.ParkingAlias,
            "parking_number": payload.ParkingNumber,
            "terminal_number": payload.TerminalNumber or 0,
            "generation_datetime": payload.GenerationDateTime.isoformat(),
            "license_plate": payload.LicensePlate,
            "ticket_number": payload.TicketNumber,
            # Para entrada, el identificador de usuario es el SupportId (QR o matrícula)
            "identificador_usuario": payload.Support.SupportId or payload.LicensePlate,
            "support_id": payload.Support.SupportId,
            "support_type": payload.Support.SupportType,
            "product_code": payload.Product.ProductCode,
            "product_type": payload.Product.ProductType,
        }

        sdc_extra_data = {
            "issue_datetime": payload.IssueDateTime,
            "product_type": payload.Product.ProductType,
            "product_code": payload.Product.ProductCode,
            "ticket_number": payload.TicketNumber,
            "parking_number": payload.ParkingNumber,
        }


        transito_service = ParkareTransito()
        result = await transito_service.notifica_transito(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            provider_name="parkare",
            notificacion_transito=notificacion_data,
            tipo_aparato="5",  # 5 = entrada vehicular
            sdc_extra_data=sdc_extra_data,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
        raise http_exc

    except Exception as e:
        logger.error(f"[ERROR] Fallo en TicketIssued: {str(e)}")
        traceback.print_exc()
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al procesar TicketIssued",
                "detail": str(e),
            },
        )


# -------------------------------------------------------------------------------------------------
# Tránsito de salida: el SDC confirma que el vehículo ha pasado la barrera de salida
# -------------------------------------------------------------------------------------------------
@router.post(
    "/ProductPass",
    summary="Notificación de paso por barrera de salida (tránsito de salida)",
    description="El SDC notifica que el vehículo ha pasado la barrera de salida. "
    "Es equivalente al tránsito de salida en otros SDCs. Solo es una notificación, no realiza autorización.",
)
async def product_pass(
    payload: ParkareProductPassRequest,
    db: Session = Depends(get_db),
):
    logger.warning(
        f"[DEBUG][ProductPass PARKARE] mat:{payload.LicensePlate} - ticket:{payload.TicketNumber} - parking:{payload.ParkingAlias}"
    )

    try:
        id_app = int(os.getenv("APP_ID"))
        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "parkare"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de parkare, revisar configuración",
                },
            )

        notificacion_data = {
            "parking_alias": payload.ParkingAlias,
            "parking_number": payload.ParkingNumber,
            "terminal_number": payload.TerminalNumber or 0,
            "generation_datetime": payload.GenerationDateTime.isoformat(),
            "license_plate": payload.LicensePlate,
            "ticket_number": payload.TicketNumber or "",
            # Para salida el identificador de usuario es el ProductCode
            "identificador_usuario": payload.Product.ProductCode or payload.LicensePlate,
            "support_id": "",
            "product_code": payload.Product.ProductCode,
            "product_type": payload.Product.ProductType,
            # EntryInfo para el resumen de estancia en salida
            "entry_info": (
                {"date_time": payload.EntryInfo.DateTime.isoformat()}
                if payload.EntryInfo
                else None
            ),
        }

        transito_service = ParkareTransito()
        result = await transito_service.notifica_transito(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            provider_name="parkare",
            notificacion_transito=notificacion_data,
            tipo_aparato="6",  # 6 = salida vehicular
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
        raise http_exc

    except Exception as e:
        logger.error(f"[ERROR] Fallo en ProductPass: {str(e)}")
        traceback.print_exc()
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al procesar ProductPass",
                "detail": str(e),
            },
        )
