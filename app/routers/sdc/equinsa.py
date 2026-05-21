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
from app.services.rotacion.equinsa import EquinsaBarrera
from app.services.rotacion.equinsa import EquinsaTransito
from dotenv import load_dotenv
from app.models.somos_configuracion import SomosConfiguracion
from app.services.notificaciontransito import NotificacionTransitoRequest
from app.services.rompetechos import RompetechosServiceRquest
import json
import logging
from app.utils.logging import crea_log

load_dotenv()

router = APIRouter(tags=["equinsa"])

logger = logging.getLogger(__name__)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.get(
    "/autorizacionUsuario",
    summary="Pedir autorización de entrada para un vehículo",
    description="Cuando un vehículo está entrando del parking, el sistema de control de acceso del parking llamará a este endpoint para solicitar la autorización de entrada. ",
)
async def autorizacion_usuario(
    id_aparcamiento: str = Query(..., description="Identificador del aparcamiento"),
    tipo_aparato: str = Query(
        ..., description="Identificador del vial por donde accede el usuario"
    ),
    numero_aparato: int = Query(
        ..., description="Numero de vial por donde accede el usuario"
    ),
    fecha_hora: datetime = Query(
        ..., description="Fecha y hora de acceso en formato ISO-8601"
    ),
    # datos_soporte: str = Query(..., description="Datos leidos del soporte (datos_soporte)"),
    numeroSerieContactless: Optional[str] = Query(
        None, description="Nº de serie de la tarjeta contactless (Ej. C284FA01)"
    ),
    codigoBarras: Optional[str] = Query(
        None,
        description="Datos obtenidos del lector de código de barras (Ej. RES-00001-03AF)",
    ),
    matricula: str = Query(..., description="Matrícula reconocida (Ej. 5970CZR)"),
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = None,
):
    id_app = int(os.getenv("APP_ID"))

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="equinsa",
        v_mysql_errno="Inicio",
    )

    try:
        service = EquinsaBarrera()

        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "equinsa"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de equinsa, revisar configuración",
                },
            )

        datos_soporte = {
            "matricula": matricula,
            "numeroSerieContactless": numeroSerieContactless,
            "codigoBarras": codigoBarras,
        }

        # Logica para definir tipo de entrada
        entrance_type = "vehicular"
        if tipo_aparato == "9":
            entrance_type = "peatonal"

        result = await service.autorizar_entrada(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            codigo_parking=id_aparcamiento,  # "1067"
            tipo_aparato=tipo_aparato,
            numero_aparato=numero_aparato,
            fecha_hora=fecha_hora,
            datos_acceso=json.dumps(datos_soporte),
            license_plate=matricula,
            provider_name="equinsa",
            entrance_type=entrance_type,
            background_tasks=background_tasks,
        )
        print(":::::::respuesta entrada", result)
        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
        raise http_exc

    except Exception as e:
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
    "/autorizacionUsuarioSalida",
    summary="Pedir autorización de salida para un vehículo",
    description="Cuando un vehículo está saliendo del parking, el sistema de control de acceso del parking llamará a este endpoint para solicitar la autorización de salida. ",
)
async def autorizacion_usuario_salida(
    id_aparcamiento: str = Query(..., description="Identificador del aparcamiento"),
    tipo_aparato: str = Query(
        ..., description="Identificador del vial por donde accede el usuario"
    ),
    numero_aparato: int = Query(
        ..., description="Número de vial por donde accede el usuario"
    ),
    fecha_hora: datetime = Query(
        ..., description="Fecha y hora local en formato ISO-8601"
    ),
    numeroSerieContactless: Optional[str] = Query(
        None, description="Nº de serie de la tarjeta contactless"
    ),
    codigoBarras: Optional[str] = Query(None, description="Código de barras escaneado"),
    matricula: str = Query(..., description="Matrícula reconocida"),
    ticket: str = Query(None, description="Ticket de salida"),
    db: Session = Depends(get_db),
):
    id_app = int(os.getenv("APP_ID"))

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="equinsa",
        v_mysql_errno="Inicio",
    )

    try:
        service = EquinsaBarrera()

        id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "equinsa"))

        if not id_sdc:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc para equinsa",
                },
            )

        datos_salida = {
            "matricula": matricula,
            "numeroSerieContactless": numeroSerieContactless,
            "codigoBarras": codigoBarras,
            "cierre_manual": False,
            "observaciones": "",
            "foto": "",
            "fecha_entrada": None,
        }

        result = await service.autorizar_salida(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            codigo_parking=id_aparcamiento,
            tipo_aparato=tipo_aparato,
            numero_aparato=numero_aparato,
            ticket=ticket,
            fecha_hora=fecha_hora,
            datos=json.dumps(datos_salida),
            provider_name="equinsa",
            license_plate=matricula,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as http_exc:
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
    "/notificacionTransito",
    summary="Notificación de tránsito de un vehiculo para confirmar su entrada o salida del parking",
    description="Notificación de tránsito de un vehiculo para confirmar su entrada o salida del parking. "
    "Este servicio solo es para notificación, no realiza ninguna acción de autorización, se debería"
    "usar junto con la correspondiente autorización de entrada o de salida, pero no implica nada el no "
    "utilizarla o un error en el servicio",
)
async def notificacion_transito(
    notificacion_transito: NotificacionTransitoRequest, db: Session = Depends(get_db)
):
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}), # v_log=str(notificacion_transito.model_dump()),
        v_user="equinsa",
        v_mysql_errno="Inicio",
    )

    try:
        servicio = EquinsaTransito()

        id_app = 1  # int(os.getenv("APP_ID"))
        id_sdc = (
            1  # int(SomosConfiguracion.get_value(db, id_app, "codigos", "equinsa"))
        )

        if not id_sdc or not id_app:
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "status": "error",
                    "message": "No se pudo encontrar el id_sdc de equinsa o de aplicación, revisar configuración",
                },
            )

        result = await servicio.notifica_transito(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            provider_name="equinsa",
            notificacion_transito=notificacion_transito,
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
                "message": f"Error al procesar autorización de entrada",
                "detail": str(e),
            },
        )


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
    salida: Optional[str] = Query(
        None, description="Fecha de salida en formato YYYY-MM-DDTHH:MM:SS"
    ),
    entrada: str = Query(
        "",
        description="Fecha de entrada en formato YYYY-MM-DDTHH:MM:SS",
    ),
    fecha_cobro: Optional[str] = Query(
        None,
        description="formato YYYY-MM-DDTHH:MM:SS. Cuando el cliente ya ha pagado al menos una vez y se ha pasado del tiempo de cortesia, aquí debe ir la fecha en la que se hizo ese pago.",
    ),
    ticket: str = Query(None, description="Ticket de salida"),
    codigoPromocion: Optional[str] = Query(None, description="Codigo de promoción"),
    db: Session = Depends(get_db),
):
    await crea_log(
        db=db,
        # v_log=str({"matricula": matricula, "parking": id_aparcamiento, "token": token[:8]+"...", "ticket": ticket, "entrada": entrada, "salida": salida, "fecha_cobro": fecha_cobro, "codigoPromocion": codigoPromocion}),
        v_log=str({"Parametros":locals()}),
        v_user="equinsa",
        v_mysql_errno="Inicio",
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
            entrada=entrada
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
