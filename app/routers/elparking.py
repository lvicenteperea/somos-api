import os
from typing import List
from fastapi import APIRouter, status, Depends, HTTPException, Request, Query, Body
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session
from app.config.db import get_db
from app.schemas.elparking import (
    CreateBookingRequestEP,
    EditBookingRequest,
    ParkingAvailabilityItemEP,
    GetBookingResponseEP,
    CreateBookingResponseEP,
    EditBookingResponseEP,
    DeleteBookingResponseEP,
    AVAILABILITY_400_RESPONSE,
    BOOKING_CREATION_400_RESPONSE,
)
from app.utils.auth import get_jwt_token
from app.services.reservas.elparking import ReservasServiceElParking
import traceback
from app.models.somos_configuracion import SomosConfiguracion
from app.utils.logging import crea_log

router = APIRouter(tags=["elparking"])


# -------------------------------------------------------------------------------------------------
@router.get(
    "/bookings-available",
    response_model=list[ParkingAvailabilityItemEP],
    summary="Consultar disponibilidad y precios",
    description="Obtiene la disponibilidad y precios de reservas para uno o varios parkings en las fechas indicadas. Devuelve un listado con el precio, plazas disponibles y token de precio (priceId) necesario para crear la reserva.",
    responses={400: AVAILABILITY_400_RESPONSE},
)
async def availability_and_price(
    request: Request,
    parkings: str = Query(
        ..., description="Lista de IDs de parkings separados por coma"
    ),
    arrival_date_time: str = Query(
        ..., description="Fecha y hora de llegada (formato ISO 8601, ej: 2026-03-27T14:30:00Z)"
    ),
    departure_date_time: str = Query(
        ..., description="Fecha y hora de salida (formato ISO 8601, ej: 2026-03-27T18:00:00Z)"
    ),
    db: Session = Depends(get_db),
) -> list[ParkingAvailabilityItemEP]:
    """
    Obtener disponibilidad y precios de estacionamientos.
    """
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="elparking",
        v_mysql_errno="Inicio",
    )
    try:
        # Obtener configuración desde la base de datos, env o fijos
        id_app = int(os.getenv("APP_ID"))
        modified_by = os.getenv("USER_ELPARKING", "ElParking")
        id_partner = int(
            SomosConfiguracion.get_value(db, id_app, "codigos", "elparking")
        )

        # Convertir de "2026-03-27T14:30:00Z" al formato que espera el servicio ("YYYY-MM-DD HH:MM:SS")
        from datetime import datetime as _dt
        entry_date = _dt.strptime(arrival_date_time, "%Y-%m-%dT%H:%M:%SZ").strftime("%Y-%m-%d %H:%M:%S")
        exit_date = _dt.strptime(departure_date_time, "%Y-%m-%dT%H:%M:%SZ").strftime("%Y-%m-%d %H:%M:%S")


        reservas_service = ReservasServiceElParking()

        result = await reservas_service.availability_and_price(
            db=db,
            user=modified_by,
            id_app=id_app,
            parkings=parkings,
            id_partner=id_partner,
            partner_real="TODOS",
            fecha_entrada=entry_date,
            fecha_salida=exit_date,
            timeout=60,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as e:
        raise e
    except Exception as e:
        print(traceback.format_exc())
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al consultar disponibilidad y precios: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.get(
    "/bookings/{id}",
    response_model=GetBookingResponseEP,
    summary="Obtener reserva por ID",
    description="Recupera la información completa de una reserva existente usando su identificador (token). Incluye fechas, matrícula, precio, códigos de acceso peatonal y QR.",
)
async def get_booking(
    id: str, db: AsyncSession = Depends(get_db)
) -> GetBookingResponseEP:
    """
    Obtener información de una reserva específica.
    Requiere autenticación Basic Auth.
    """
    reservas_service = ReservasServiceElParking()

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="elparking",
        v_mysql_errno="Inicio",
    )

    try:
        result = await reservas_service.obtener_reserva(db, id)
        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException as e:
        raise e


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.post(
    "/bookings",
    status_code=status.HTTP_201_CREATED,
    response_model= CreateBookingResponseEP,
    summary="Crear nueva reserva",
    description="Crea una nueva reserva de parking. Requiere el priceId obtenido previamente del endpoint /bookings-available, junto con los datos del cliente y fechas de entrada/salida. Devuelve la reserva creada con sus códigos de acceso.",
    responses={400: BOOKING_CREATION_400_RESPONSE},
)
async def create_booking(
    booking_data: CreateBookingRequestEP,
    db: AsyncSession = Depends(get_db),
) -> CreateBookingResponseEP:
    """
    Crear una nueva reserva.
    Requiere autenticación Basic Auth.
    """
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="elparking",
        v_mysql_errno="Inicio",
    )
    try:
        # Utilizar el servicio para crear la reserva
        reservas_service = ReservasServiceElParking()

        # # Convertir las fechas y horas a objetos datetime
        # fecha_entrada = booking_data.get_arrival_datetime()
        # fecha_salida = booking_data.get_departure_datetime()

        # # Preparar los datos del cliente en formato JSON
        # datos_cliente = booking_data.get_client_data_json()

        # Llamar al servicio para crear la reserva
        result = await reservas_service.crear_reserva(db=db, datos=booking_data)

        # Devolver la respuesta con los datos de la reserva creada
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear la reserva: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.patch(
    "/bookings/{id}",
    response_model=EditBookingResponseEP,
    summary="Editar reserva existente",
    description="Modifica una reserva existente. Actualmente permite actualizar la matrícula del vehículo asociado a la reserva. Sincroniza los cambios con el sistema de control de acceso (SDC).",
)
async def edit_booking(
    id: str,
    booking_data: EditBookingRequest = Body(
        example={
            "license_plate": "1234ABC",
            "arrival_date_time": "2026-03-27T14:30:00Z",
            "departure_date_time": "2026-03-27T18:00:00Z",
            "observations": "Cambio de matrícula",
        }
    ),
    db: AsyncSession = Depends(get_db),
) -> EditBookingResponseEP:
    """
    Editar una reserva existente (actualizar matrícula).
    Requiere autenticación Basic Auth.
    """
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="elparking",
        v_mysql_errno="Inicio",
    )
    reservas_service = ReservasServiceElParking()
    user = os.getenv("USER_ELPARKING", "ElParking")
    observations = booking_data.observations if booking_data.observations else "Observaciones no proporcionadas"
    result = await reservas_service.editar_reserva(
        db, id, booking_data.license_plate, booking_data.get_arrival_datetime(), booking_data.get_departure_datetime(), user=user, observations=observations
    )

    return JSONResponse(status_code=status.HTTP_200_OK, content=result)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.delete(
    "/bookings/{id}",
    response_model=DeleteBookingResponseEP,
    summary="Cancelar reserva",
    description="Cancela una reserva existente. Elimina la reserva del sistema de control de acceso (SDC) y, si procede, gestiona la devolución del pago asociado.",
)
async def delete_booking(
    id: str, db: AsyncSession = Depends(get_db)
) -> DeleteBookingResponseEP:
    """
    Eliminar (cancelar) una reserva existente.
    Requiere autenticación Basic Auth.
    """
    id_app = int(os.getenv("APP_ID"))
    id_partner = int(SomosConfiguracion.get_value(db, id_app, "codigos", "elparking"))
    print("::::id partner para eliminar reserva::::", id_partner)

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="elparking",
        v_mysql_errno="Inicio",
    )
    reservas_service = ReservasServiceElParking()
    result = await reservas_service.eliminar_reserva(
        db, id, id_partner, user="ElParking"
    )

    return JSONResponse(status_code=status.HTTP_200_OK, content=result)
