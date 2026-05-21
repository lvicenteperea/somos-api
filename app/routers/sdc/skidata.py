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
from app.services.rotacion.skidata import SkidataBarrera, SkidataTransito
from dotenv import load_dotenv
from app.models.somos_configuracion import SomosConfiguracion
from app.services.notificaciontransito import NotificacionTransitoRequest
from app.services.rompetechos import RompetechosServiceRquest
from app.schemas.skidata.schemas import SkidataAccessRequest
import logging
import json

load_dotenv()

router = APIRouter(tags=["skidata"])

logger = logging.getLogger(__name__)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.get(
    "/EntryAuthorization",
    summary="Pedir autorización de entrada para un vehículo",
    description="Cuando un vehículo está entrando del parking, el sistema de control de acceso del parking llamará a este endpoint para solicitar la autorización de entrada. ",
)
async def autorizacion_usuario_entrada(
    parking_id: str = Query(..., description="Identificador del aparcamiento"),
    device_type: str = Query(
        ...,
        description="Identificador del tipo de máquina: Entrada (2), Salida (3), Abre Puertas (5), Columna de transferencia (7)",
    ),
    machine_id: int = Query(..., description="Número del tipo de aparato"),
    date_time: datetime = Query(
        ..., description="Fecha y hora de acceso en formato ISO-8601"
    ),
    identifier: str = Query(
        ...,
        description="Identificador del vehículo: matrícula (identifier_type=P) o código de barras (identifier_type=B)",
    ),
    identifier_type: str = Query(
        ...,
        description="Tipo de identificador del vehículo: P (matrícula) o B (código de barras)",
    ),
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = None,
):
    logger.warning(
        f"[DEBUG][llamada a autorizacionUsuario SKIDATA] : identifier:{identifier} (type:{identifier_type}) - {parking_id}-{device_type}-{machine_id}"
    )

    try:
        service = SkidataBarrera()

        id_app = int(os.getenv("APP_ID"))
        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "skidata"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de skidata, revisar configuración",
                },
            )

        # Mapear indentifier según Indentifier_type (P=matrícula, B=código de barras)
        matricula = identifier if identifier_type == "P" else ""
        codigoBarras = identifier if identifier_type == "B" else ""

        datos_soporte = {
            "matricula": matricula,
            "numeroSerieContactless": "",  # Skidata no envía este campo
            "codigoBarras": codigoBarras,
        }

        # TODO: Hay entradas peatonales?
        entrance_type = "vehicular" if device_type in ("2", "3") else "peatonal"

        result = await service.autorizar_entrada(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            codigo_parking=parking_id,
            tipo_aparato=device_type,
            numero_aparato=machine_id,
            fecha_hora=date_time,
            datos_acceso=json.dumps(datos_soporte),
            license_plate=matricula,
            provider_name="skidata",
            entrance_type=entrance_type,
            background_tasks=background_tasks,
        )

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
# -------------------------------------------------------------------------------------------------
@router.get(
    "/ExitAuthorization",
    summary="Pedir autorización de salida para un vehículo",
    description="Cuando un vehículo está saliendo del parking, el sistema de control de acceso del parking llamará a este endpoint para solicitar la autorización de salida. ",
)
async def autorizacion_usuario_salida(
    parking_id: str = Query(..., description="Identificador del aparcamiento"),
    identifier: str = Query(
        ...,
        description="Identificador del vehículo: matrícula (identifier_type=P) o código de barras (identifier_type=B)",
    ),
    identifier_type: str = Query(
        ...,
        description="Tipo de identificador del vehículo: P (matrícula) o B (código de barras)",
    ),
    device_type: str = Query(
        ...,
        description="Identificador del tipo de máquina: Entrada (2), Salida (3), Abre Puertas (5), Columna de transferencia (7)",
    ),
    machine_id: int = Query(..., description="Número del tipo de aparato"),
    external_id: str = Query(
        ...,
        description="Identificador del tránsito recibido en la respuesta de EntryAuthorization",
    ),
    date_time: datetime = Query(
        ..., description="Fecha y hora de acceso en formato ISO-8601"
    ),
    amount: float = Query(
        ..., description="Importe pagado por el usuario en la salida"
    ),
    db: Session = Depends(get_db),
):
    # Mapear identifier según identifier_type (P=matrícula, B=código de barras)
    matricula = identifier if identifier_type == "P" else ""
    codigoBarras = identifier if identifier_type == "B" else ""

    logger.warning(
        f"[DEBUG][llamada a ExitAuthorization skidata] : identifier:{identifier} (type:{identifier_type}) - {parking_id}-{device_type}-{machine_id}"
    )

    try:
        service = SkidataBarrera()

        id_app = int(os.getenv("APP_ID"))
        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "skidata"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc para skidata",
                },
            )

        datos_salida = {
            "matricula": matricula,
            "numeroSerieContactless": "",
            "codigoBarras": codigoBarras,
            "external_id": external_id,
            "cierre_manual": False,
            "observaciones": "",
            "foto": "",
            "fecha_entrada": None,
        }

        # TODO: Descomentar esto!!!!
        result = await service.autorizar_salida(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            codigo_parking=parking_id,
            tipo_aparato=device_type,
            numero_aparato=machine_id,
            ticket="",  # Skidata no envía este campo
            fecha_hora=date_time,
            datos=json.dumps(datos_salida),
            license_plate=matricula,
            provider_name="skidata",
            amount=amount,
        )
        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
        print("[ERROR] Fallo en autorizacion_usuario_salida")
        traceback.print_exc()
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al procesar autorización de salida",
                "detail": str(http_exc),
                "permitir_acceso": False,
            },
        )

    except Exception as e:
        print("[ERROR] Fallo en autorizacion_usuario_salida")
        print(str(e))
        traceback.print_exc()
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al procesar autorización de salida",
                "detail": str(e),
                "permitir_acceso": False,
            },
        )


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.post(
    "/Access",
    summary="Notificación de tránsito de un vehiculo para confirmar su entrada o salida del parking",
    description="Notificación de tránsito de un vehiculo para confirmar su entrada o salida del parking. "
    "Este servicio solo es para notificación, no realiza ninguna acción de autorización, se debería"
    "usar junto con la correspondiente autorización de entrada o de salida, pero no implica nada el no "
    "utilizarla o un error en el servicio",
)
async def notificacion_transito(
    request: SkidataAccessRequest, db: Session = Depends(get_db)
):
    # Derivar matriculaVehiculo y codigoBarras desde identifier + identifier_type
    matricula = request.identifier if request.identifier_type == "P" else ""
    codigo_barras = request.identifier if request.identifier_type == "B" else ""

    logger.warning(
        f"[DEBUG][llamada a /access skidata] : identifier:{request.identifier} "
        f"(type:{request.identifier_type}) - type:{request.type} - machine_ID:{request.machine_id}"
    )
    logger.warning(request)

    try:
        servicio = SkidataTransito()

        id_app = int(os.getenv("APP_ID"))
        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "skidata"))

        if not id_sdc or not id_app:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de skidata o de aplicación, revisar configuración",
                },
            )

        # Construir el objeto que espera NotificacionTransitoService mapeando
        # los campos de Skidata a los campos internos
        resumenEstancia = {"fechaHoraSalida": request.date_time} if request.type == "Exit" else None

        notificacion = NotificacionTransitoRequest(
            codigoInstalacion=request.parking_id,
            tipo_aparato=(
                "E" if request.type == "Entry" else "S"
            ),  # "E" Entrada o "S" Salida
            numero_aparato=request.machine_id,
            fechaHora=request.date_time,
            identificadorUsuario=request.external_id,
            numeroSerieContactless="",  # Skidata no lo envía
            codigoBarras=codigo_barras,
            matriculaVehiculo=matricula,
            numeroProducto=request.ticket_id,
            resumenEstancia=resumenEstancia,
            transaction_id=request.transaction_id,
        )

        result = await servicio.notifica_transito(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            provider_name="skidata",
            notificacion_transito=notificacion,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
        raise http_exc

    except Exception as e:
        print("[ERROR] Fallo en notificacion_transito /access")
        print(str(e))
        traceback.print_exc()

        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "error",
                "message": "Error al procesar la notificación de tránsito",
                "detail": str(e),
            },
        )


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
        f"[DEBUG][llamada a precioDinamicoCajero skidata] : token:{token[:8]}... - aparcamiento:{id_aparcamiento} - salida:{salida} - matricula:{matricula} - ticket:{ticket} - codigoPromocion:{codigoPromocion}"
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
