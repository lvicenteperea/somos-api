import os
from typing import List
from fastapi import APIRouter, status, Depends, HTTPException, Request, Query
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session
from app.config.db import get_db
from app.schemas.parkings_admin import (
    LoginRequest,
    AuthResponse,
    ParkingAvailabilityItem,
    GetBookingResponse,
    CreateBookingResponse,
    EditBookingResponse,
    DeleteBookingResponse,
)
from app.schemas.reservas import CreateBookingRequest, EditBookingRequest
from app.utils.auth import get_jwt_token
from app.services.reservas.parkingsadmin import ReservasServicePA
from app.utils.logging import crea_log

# from app.utils.call_db_procedure import CoreDatabaseException

import traceback
from app.models.somos_configuracion import SomosConfiguracion

router = APIRouter(prefix="/parkings-admin", tags=["parkings_admin"])


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.post(
    "/auth",
    response_model=AuthResponse,
    summary="Autenticación de usuario",
    description="Autentica al usuario con sus credenciales (username y password) y devuelve un token JWT Bearer para usar en las siguientes peticiones.",
)
async def login(
    login_data: LoginRequest, db: AsyncSession = Depends(get_db)
) -> AuthResponse:
    """
    Endpoint para autenticar al usuario y devolver un token JWT.
    """
    token_data = await get_jwt_token(
        db,
        login_data.username,
        login_data.password,
        os.environ.get("PARKINS_ADMIN_SLUG", "parkingsadmin"),
    )

    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username or password incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return JSONResponse(status_code=status.HTTP_200_OK, content=token_data)


# -------------------------------------------------------------------------------------------------
@router.get(
    "/bookings-available",
    response_model=List[ParkingAvailabilityItem],
    summary="Consultar disponibilidad y precios",
    description="Obtiene la disponibilidad y precios de reservas para uno o varios parkings en las fechas indicadas. Devuelve un listado con el precio, plazas disponibles y token de precio (priceId) necesario para crear la reserva.",
)
async def availability_and_price(
    request: Request,
    parkings: str = Query(
        ..., description="Lista de códigos de parkings separados por coma"
    ),
    arrival_date: str = Query(..., description="Fecha de llegada (formato YYYY-MM-DD)"),
    arrival_time: str = Query(..., description="Hora de llegada (formato HH:MM)"),
    departure_date: str = Query(
        ..., description="Fecha de salida (formato YYYY-MM-DD)"
    ),
    departure_time: str = Query(..., description="Hora de salida (formato HH:MM)"),
    db: Session = Depends(get_db),
) -> List[ParkingAvailabilityItem]:
    """
    Obtener disponibilidad y precios de estacionamientos.
    """
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="parkings_admin",
        v_mysql_errno="Inicio",
    )
    try:
        # Obtener configuración desde la base de datos, env o fijos
        id_app = int(os.getenv("APP_ID"))
        modified_by = "ParkingsAdmin"
        id_partner = int(
            SomosConfiguracion.get_value(db, id_app, "codigos", "parkingsadmin")
        )

        entry_date = f"{arrival_date} {arrival_time}:00"
        exit_date = f"{departure_date} {departure_time}:00"

        reservas_service = ReservasServicePA()

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
    "/bookings/{booking_id}",
    response_model=GetBookingResponse,
    summary="Obtener información de una reserva",
    description="Obtiene la información detallada de una reserva específica mediante su ID (token). Incluye fechas, matrícula, códigos de acceso y estado de cancelación.",
)
async def get_booking(
    booking_id: str, request: Request, db: AsyncSession = Depends(get_db)
) -> GetBookingResponse:
    """
    Obtener información de una reserva específica.
    Requiere autenticación JWT.
    """
    # Utilizar el servicio para obtener la reserva
    reservas_service = ReservasServicePA()

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="parkings_admin",
        v_mysql_errno="Inicio",
    )

    try:
        result = await reservas_service.obtener_reserva(db, booking_id)
        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException as e:
        # Re-lanzar la excepción para mantener el código de estado
        raise e


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.post(
    "/bookings",
    status_code=status.HTTP_201_CREATED,
    response_model=CreateBookingResponse,
    summary="Crear una nueva reserva",
    description="Crea una nueva reserva de parking con los datos proporcionados. Requiere un priceId válido obtenido del endpoint /bookings-available. Devuelve la información completa de la reserva creada incluyendo códigos de acceso.",
)
async def create_booking(
    booking_data: CreateBookingRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> CreateBookingResponse:
    """
    Crear una nueva reserva.
    Requiere autenticación JWT.
    """
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}), # v_log=str(booking_data.model_dump()),
        v_user="parkings_admin",
        v_mysql_errno="Inicio",
    )
    try:
        # Utilizar el servicio para crear la reserva
        reservas_service = ReservasServicePA()

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
    "/bookings/{booking_id}",
    response_model=EditBookingResponse,
    summary="Editar una reserva existente",
    description="Actualiza la matrícula de una reserva existente. Sincroniza el cambio con el sistema de control del parking (SDC).",
)
async def edit_booking(
    booking_id: str,
    booking_data: EditBookingRequest,
    db: AsyncSession = Depends(get_db),
) -> EditBookingResponse:
    """
    Editar una reserva existente.
    Requiere autenticación JWT.
    """
    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="parkings_admin",
        v_mysql_errno="Inicio",
    )
    reservas_service = ReservasServicePA()
    result = await reservas_service.editar_reserva(
        db, booking_id, booking_data.licensePlate
    )

    return JSONResponse(status_code=status.HTTP_200_OK, content=result)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.delete(
    "/bookings/{booking_id}",
    response_model=DeleteBookingResponse,
    summary="Eliminar una reserva",
    description="Cancela y elimina una reserva existente. Sincroniza la cancelación con el sistema de control del parking (SDC) y gestiona la devolución del pago si corresponde.",
)
async def delete_booking(
    booking_id: str, request: Request, db: AsyncSession = Depends(get_db)
) -> DeleteBookingResponse:
    """
    Eliminar una reserva existente.
    Requiere autenticación JWT.
    """
    id_app = int(os.getenv("APP_ID"))
    # id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "parkingsadmin"))
    id_partner = int(
        SomosConfiguracion.get_value(db, id_app, "codigos", "parkingsadmin")
    )

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="parkings_admin",
        v_mysql_errno="Inicio",
    )
    reservas_service = ReservasServicePA()
    result = await reservas_service.eliminar_reserva(
        db, booking_id, id_partner, user="ParkingsAdmin"
    )

    # Devolver respuesta sin contenido para una eliminación correcta
    return JSONResponse(status_code=status.HTTP_200_OK, content=result)
