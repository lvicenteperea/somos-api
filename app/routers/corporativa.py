from fastapi import APIRouter, status, HTTPException, Request, Depends
from fastapi.responses import JSONResponse

from dotenv import load_dotenv
import os
from sqlalchemy.ext.asyncio import AsyncSession

# from app.models.somos_configuracion import SomosConfiguracion

from typing import Optional

from app.config.db import get_db
from app.utils.auth import get_jwt_token

# -------------------------------------------------------------------------------------------------
load_dotenv()
router = APIRouter(prefix="/crprtv", tags=["Corporativa"])

# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
from app.schemas.auth import LoginRequest
from app.schemas.corporativa import AuthResponse


@router.post(
    "/auth",
    response_model=AuthResponse,
    summary="Autenticación de usuario corporativo",
    description="Autentica al usuario con credenciales y devuelve un token JWT para acceder a los endpoints protegidos.",
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
        os.environ.get("SOMOS_SLUG", "somos"),
    )
    # os.environ.get('CORPORATIVA_SLUG', '6'))

    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username or password incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return JSONResponse(status_code=status.HTTP_200_OK, content=token_data)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para la gestión de RESERVAS
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
from app.schemas.reservas import (
    CreateBookingRequest,
)  # Importar los esquemas de reservas
from app.services.reservas.corporativa import ReservasServiceCORP
from app.schemas.corporativa import CreateBookingResponse


# -------------------------------------------------------------------------------------------------
@router.post(
    "/bookings",
    status_code=status.HTTP_201_CREATED,
    response_model=CreateBookingResponse,
    summary="Crear reserva corporativa",
    description="Crea una nueva reserva para un cliente corporativo. "
    "Requiere autenticación JWT. Devuelve los datos de la reserva creada "
    "incluyendo códigos de acceso peatonal y QR.",
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
    try:
        # result = {"mensaje": f"Servicio de reservas no implementado aún. Datos enviados: {booking_data.dict()}"}
        # return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

        # Utilizar el servicio para crear la reserva
        reservas_service = ReservasServiceCORP()

        # Llamar al servicio para crear la reserva
        result = await reservas_service.crear_reserva(
            db=db, request=request, datos=booking_data
        )
        # Devolver la respuesta con los datos de la reserva creada
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el booking: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
@router.patch("/bookings/{booking_id}")
async def edit_booking(
    booking_id: str, request: Request, db: AsyncSession = Depends(get_db)
):
    """
    Editar una reserva existente.
    Requiere autenticación JWT.
    """
    # Obtener el body de la petición
    body = await request.json()

    # Validar que llegue el parámetro licensePlate en el body
    if "licensePlate" not in body:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El parámetro 'licensePlate' es obligatorio",
        )

    # Obtener el valor de la matrícula
    license_plate = body["licensePlate"]

    # Utilizar el servicio para editar la reserva
    reservas_service = ReservasServiceCORP()
    result = await reservas_service.editar_reserva(db, booking_id, license_plate)

    return JSONResponse(status_code=status.HTTP_200_OK, content=result)


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
from app.schemas.corporativa import ListadoReservaItem
from typing import List


@router.get(
    "/bookings/listado",
    status_code=status.HTTP_200_OK,
    response_model=List[ListadoReservaItem],
    summary="Listado de reservas corporativas",
    description="Obtiene un listado de reservas según filtros de centro, fechas y matrícula. "
    "Retorna un array de objetos con la información de las reservas.",
)
async def listar_reservas(
    acronimo_centro: str,
    fecha_desde: str,
    fecha_hasta: Optional[str] = None,
    matricula: Optional[str] = None,
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> List[ListadoReservaItem]:
    """
    Obtiene un listado de reservas según filtros de centro, fechas y matrícula.
    Retorna un JSON con una lista de diccionarios.
    """
    try:
        reservas_service = ReservasServiceCORP()
        result = await reservas_service.listar_reservas(
            db=db,
            request=request,
            acronimo_centro=acronimo_centro,
            fecha_desde=fecha_desde,
            fecha_hasta=fecha_hasta,
            matricula=matricula,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener el listado de reservas: {str(e)}",
        )


'''
# -------------------------------------------------------------------------------------------------
@router.get("/bookings/{booking_id}")
async def get_booking(booking_id: str, request: Request, db: AsyncSession = Depends(get_db)):
    """
    Obtener información de una reserva específica.
    Requiere autenticación JWT.
    """
    # Utilizar el servicio para obtener la reserva
    reservas_service = ReservasServiceCORP()
    
    try:
        result = await reservas_service.obtener_reserva(db, booking_id)
        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException as e:
        # Re-lanzar la excepción para mantener el código de estado
        raise e


# -------------------------------------------------------------------------------------------------
@router.patch("/bookings/{booking_id}")
async def edit_booking(booking_id: str, request: Request, db: AsyncSession = Depends(get_db)):
    """
    Editar una reserva existente.
    Requiere autenticación JWT.
    """
    # Obtener el body de la petición
    body = await request.json()
    
    # Validar que llegue el parámetro licensePlate en el body
    if "licensePlate" not in body:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El parámetro 'licensePlate' es obligatorio"
        )
    
    # Obtener el valor de la matrícula
    license_plate = body["licensePlate"]
    
    # Utilizar el servicio para editar la reserva
    reservas_service = ReservasServiceBo()
    result = await reservas_service.editar_reserva(db, booking_id, license_plate)
    
    return JSONResponse(status_code=status.HTTP_200_OK, content=result)
'''
# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de RESERVAS
# -------------------------------------------------------------------------------------------------



# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para la gestión de FORMULARIOS WordPress
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
'''
from app.schemas.form_wordpress import (
    CreateAbnLocalRequest, # CreateBookingRequest,
)  # Importar los esquemas de formuarios de WordPress

from app.services.form_wordpress import  FormWordPressServiceCORP  #ReservasServiceCORP
from app.schemas.corporativa import AltaAbnLocalResponse # CreateBookingResponse


# -------------------------------------------------------------------------------------------------
from pathlib import Path
from typing import Optional
from fastapi import UploadFile, File, Depends
import shutil
import uuid
import os

UPLOAD_DIR = Path("uploads/abonos/locales")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

def save_pdf(upload: UploadFile, dest: Path) -> None:
    # (Opcional) valida que sea PDF
    if upload.content_type != "application/pdf":
        raise ValueError(f"{upload.filename} no es PDF")
    with dest.open("wb") as f:
        shutil.copyfileobj(upload.file, f)

@router.post(
    "/form-WP/alta-abn-local-datos-base",
    status_code=status.HTTP_201_CREATED,
    response_model=AltaAbnLocalResponse,
    summary="Crea los datos de apoyo para un abonado local que daremos de alta por el Backoffice.",
    description="Crea los datos de apoyo para un abonado local que daremos de alta por el Backoffice. "
    "Requiere autenticación JWT.  "
)

async def create_abn_local_endpoint(
        request: Request,
        db: AsyncSession = Depends(get_db),
        datos: CreateAbnLocalRequest = Depends(CreateAbnLocalRequest.as_form),
    ):
    try:

        # Utilizar el servicio 
        altasAbnLocal_service = FormWordPressServiceCORP()
        # Llamar al servicio 
        result = await altasAbnLocal_service.crear_datos_apoyo(db=db
                                                              ,request=request
                                                              ,datos=datos
                                                              ,user=os.getenv("USER_CORP")
                                                              )
        # Devolver la respuesta con los datos de la reserva creada
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        print(f"[[[DEBUG]]] Error HTTP create_abn_local_endpoint: {e}")   
        raise e
    except Exception as e:
        print(f"[[[DEBUG]]] Error create_abn_local_endpoint: {e}")   
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el booking: {str(e)}",
        )
'''

# -------------------------------------------------------------------------------------------------
from app.schemas.ejecutor import ServicioEjecutorRequest, ServicioEjecutorResponse
from app.services.ejecutor.ejecutor import ServiceEjecutor

@router.post(
    "/integracion-externa/ejecuta-servicio",
    status_code=status.HTTP_200_OK,
    response_model=ServicioEjecutorResponse,
    summary="Ejecuta un servicio interno registrado",
    description="Recibe un nombre lógico de servicio y sus parámetros en JSON. Requiere autenticación JWT.",
)
async def ejecuta_servicio_endpoint(
    payload: ServicioEjecutorRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    try:
        ejecutor = ServiceEjecutor()

        result = await ejecutor.execute(
            nombre_servicio=payload.nombre_servicio,
            params=payload.params,
            db=db,
            request=request,
        )

        return ServicioEjecutorResponse(
            ok=True,
            nombre_servicio=payload.nombre_servicio,
            result=result,
        )

    except HTTPException as e:
        print(f"[[[DEBUG]]] Error HTTP execute_service_endpoint: {e}")
        raise e
    except Exception as e:
        print(f"[[[DEBUG]]] Error execute_service_endpoint: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al ejecutar el servicio: {str(e)}",
        )
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de FORMULARIOS WordPress
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------

