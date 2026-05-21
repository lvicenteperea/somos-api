from fastapi import (
    APIRouter,
    status,
    HTTPException,
    Request,
    Depends,
    Path,
    Query,
)
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
import os
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import List
import traceback
from app.models.somos_configuracion import SomosConfiguracion
from typing import Optional
from app.schemas.backoffice import (
    BookingResponse,
    BookingAvailabilityItem,
    ContadorItem,
    AuthResponse,
    CreateBookingResponse,
    EditBookingResponse,
    DeleteBookingResponse,
    AbonoAvailableResponse,
    CreateAbonoResponse,
    DeleteAbonoResponse,
    CreateClienteResponse,
    TanteaBajaClienteResponse,
    BajaClienteResponse,
    DatosFacturacionClienteResponse,
    SendHtmlMessageRequest,
    CargaSaldoColaboradorRequest,
    CargaSaldoColaboradorResponse,
)

from app.schemas.vehiculos import (
    CreateVehiculoRequest,
    VehiculoResponse,
    AltaVehiculoResponse,
    ModVehiculoResponse,
    BajaVehiculoResponse,
    VehiculoDentroFueraResponse,
)
from app.services.contadores import ContadoresService

from app.schemas.backoffice import FacTicketApkItem
from app.schemas.auth import LoginRequest

from app.schemas.reservas import (
    CreateBookingRequest,
)  # Importar los esquemas de reservas
from app.services.raspberry import RaspberryService
from app.services.reservas.backoffice import ReservasServiceBo
from app.services.configuracion.backoffice import ConfiguracionServiceBo
from app.services.colaboradores.carga_saldo import CargaSaldoColaboradorService
from app.utils.auth import get_jwt_token

from app.schemas.abonos import CreateAbonoRequest  # Importar los esquemas de abonos
from app.services.abonos import AbonosService

from app.schemas.clientes import (
    CreateClienteRequest,
)  # Importar los esquemas de clientes
from app.services.clientes import ClientesCreateService

from app.services.vehiculos import VehiculosServiceRequest
from app.schemas.barreras import BarrerasRequest, BarreraResponse
from app.services.barreras import BarrerasService
from app.services.rompetechos import RompetechosServiceRquest
from app.schemas.backoffice import FacAparcamientoDiaItem
from app.config.db import get_db
from app.utils.dates import ahora
from app.utils.logging import crea_log

load_dotenv()

router = APIRouter(prefix="/bo", tags=["bo"])


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------


class ContadoresRequest(BaseModel):
    apk: List[str] = [""]  # nemotécnico del aparcamiento en somos

    model_config = {
        "json_schema_extra": {"examples": [{"apk": ["APK001", "APK002", "APK003"]}]}
    }


@router.get(
    "/contadores",
    response_model=List[ContadorItem],
    status_code=status.HTTP_200_OK,
    summary="Consultar contadores de aparcamientos",
    description="Obtiene el estado de los contadores (plazas libres, ocupadas, etc.) de uno o varios aparcamientos.",
)
async def contadores(
    contadores_data: ContadoresRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> List[ContadorItem]:
    """
    Ver contadores de aparcamientos.
    Requiere autenticación JWT.
    """
    try:
        contadores_service = ContadoresService()

        # Llamar al servicio para crear la reserva
        result = await contadores_service.contadores(
            db=db, canal="BO", apk=contadores_data.apk
        )

        # Devolver la respuesta con los datos de la reserva creada
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error servicio contadores: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------

# class BookingsAvaiableRequest(BaseModel):
#     parkings: List[str]
#     arrival_date: str
#     arrival_time: str
#     departure_date: str
#     departure_time: str


@router.post(
    "/auth",
    response_model=AuthResponse,
    summary="Autenticación de usuario",
    description="Autentica al usuario con sus credenciales y devuelve un token JWT para acceder a los endpoints protegidos.",
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


@router.get(
    "/bookings-available",
    response_model=List[BookingAvailabilityItem],
    summary="Consultar disponibilidad y precios de reservas",
    description="Obtiene la disponibilidad y precios de reservas para uno o varios aparcamientos en un rango de fechas.",
)
async def availability_and_price(
    request: Request,
    parkings: str = Query(...),
    arrival_date: str = Query(...),
    arrival_time: str = Query(...),
    departure_date: str = Query(...),
    departure_time: str = Query(...),
    cod_promocion: Optional[str] = Query(None),  # ✅ Opcional, por defecto None
    db: Session = Depends(get_db),
) -> List[BookingAvailabilityItem]:


    print('  ------->>>');
    print('  ------->>>  Parámetros recibidos en availability_and_price');
    print('  ------->>>');

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="backoffice",
        v_mysql_errno="Inicio",
    )

    try:
        # Obtener configuración desde la base de datos, env o fijos
        id_app = int(os.getenv("APP_ID"))
        modified_by = "BackOffice"
        id_partner = int(SomosConfiguracion.get_value(db, id_app, "codigos", "somos"))

        entry_date = f"{arrival_date} {arrival_time}:00"
        exit_date = f"{departure_date} {departure_time}:00"

        reservas_service = ReservasServiceBo()

        result = await reservas_service.availability_and_price(
            db=db,
            user=modified_by,
            id_app=id_app,
            parkings=parkings,
            id_partner=id_partner,
            partner_real="TODOS",
            fecha_entrada=entry_date,
            fecha_salida=exit_date,
            cod_promocion=cod_promocion,
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


@router.get(
    "/bookings/{booking_id}",
    response_model=BookingResponse,
    summary="Obtener información de una reserva",
    description="Obtiene la información detallada de una reserva específica mediante su ID.",
)
async def get_booking(
    booking_id: str, request: Request, db: AsyncSession = Depends(get_db)
) -> BookingResponse:
    """
    Obtener información de una reserva específica.
    Requiere autenticación JWT.
    """
    # Utilizar el servicio para obtener la reserva
    reservas_service = ReservasServiceBo()

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="backoffice",
        v_mysql_errno="Inicio",
    )

    try:
        result = await reservas_service.obtener_reserva(db, booking_id)
        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException as e:
        # Re-lanzar la excepción para mantener el código de estado
        raise e


# -------------------------------------------------------------------------------------------------


@router.post(
    "/bookings",
    response_model=CreateBookingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una nueva reserva",
    description="Crea una nueva reserva de aparcamiento con los datos proporcionados.",
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
        v_log=str({"Parametros":locals()}),
        v_user="backoffice",
        v_mysql_errno="Inicio",
    )

    try:
        # Utilizar el servicio para crear la reserva
        reservas_service = ReservasServiceBo()
        # Llamar al servicio para crear la reserva
        result = await reservas_service.crear_reserva(
            db=db, request=request, datos=booking_data
        )

        # Devolver la respuesta con los datos de la reserva creada
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el booking: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------


@router.patch(
    "/bookings/{booking_id}",
    response_model=EditBookingResponse,
    summary="Editar una reserva existente",
    description="Modifica los datos de una reserva, principalmente la matrícula del vehículo.",
)
async def edit_booking(
    booking_id: str, request: Request, db: AsyncSession = Depends(get_db)
) -> EditBookingResponse:
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

    # Definir valores necesarios para la edición de la reserva
    license_plate = body["licensePlate"]
    arrival_datetime = body.get("llegada", None)
    departure_datetime = body.get("salida", None)
    observations = body.get("observaciones", None)
    user = body.get("user", os.getenv("USER_BACKOFFICE"))

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="backoffice",
        v_mysql_errno="Inicio",
    )

    # Utilizar el servicio para editar la reserva
    reservas_service = ReservasServiceBo()
    result = await reservas_service.editar_reserva(
        db,
        booking_id,
        license_plate,
        arrival_datetime,
        departure_datetime,
        observations,
        user,
    )
    print("Resultado edición reserva:", result)

    return JSONResponse(status_code=status.HTTP_200_OK, content=result)


# -------------------------------------------------------------------------------------------------


@router.delete(
    "/bookings/{booking_id}",
    response_model=DeleteBookingResponse,
    summary="Eliminar reserva",
    description="Elimina una reserva existente del sistema y del sistema de control (SDC). Requiere autenticación JWT.",
)
async def delete_booking(
    booking_id: str, request: Request, db: AsyncSession = Depends(get_db)
):
    """
    Eliminar una reserva existente.
    Requiere autenticación JWT.
    """

    # Obtener configuración desde la base de datos, env o fijos
    id_app = int(os.getenv("APP_ID"))
    # id_sdc = int(SomosConfiguracion.get_value(db, id_app, "codigos", "parkingsadmin"))
    id_partner = int(SomosConfiguracion.get_value(db, id_app, "codigos", "somos"))

    await crea_log(
        db=db,
        v_log=str({"Parametros":locals()}),
        v_user="backoffice",
        v_mysql_errno="Inicio",
    )

    # Utilizar el servicio para eliminar la reserva
    reservas_service = ReservasServiceBo()
    result = await reservas_service.eliminar_reserva(
        db, booking_id, id_partner, user="BackOffice"
    )

    # Devolver respuesta sin contenido para una eliminación correcta
    return JSONResponse(status_code=status.HTTP_200_OK, content=result)


# Tarifas del sdc al BO
@router.get(
    "/tarifas-sdc",
    # response_model=TarifasSdcBoResponse,
    summary="Obtener tarifas del SdC al BO",
    description="Obtiene la información de las tarifas del SdC al BO.",
)
async def get_rates_sdc(
    id_sede: int = Query(..., description="ID de la sede"),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """
    Obtiene la información de las tarifas del SdC al BO.
    """
    try:
        tarifas_service = ConfiguracionServiceBo()
        result = await tarifas_service.get_price_lists(db=db, id_sede=id_sede)

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener las tarifas del SdC al BO: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de RESERVAS
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para la gestión de ABONOS
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------


@router.get(
    "/abonos-available",
    response_model=AbonoAvailableResponse,
    summary="Consultar disponibilidad y precio de abono",
    description="Obtiene el precio y disponibilidad de un abono para una sede y producto específicos.",
)
async def availability_and_price(
    request: Request,
    id_app: int = Query(..., description="ID de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la consulta"),
    id_sede: int = Query(..., description="ID de la sede"),
    id_partner: int = Query(..., description="ID del partner"),
    arrival_date: str = Query(..., description="Fecha de entrada: yyyy-mm-dd"),
    id_prod_det: int = Query(..., description="ID del abono en prd_abonos"),
    id_producto: int = Query(..., description="ID del producto abono para validación"),
    id_frecuencia: int = Query(..., description="ID de la frecuencia del abono"),
    db: Session = Depends(get_db),
) -> AbonoAvailableResponse:

    try:
        # id_app = int(os.getenv("APP_ID"))
        # id_partner  = int(SomosConfiguracion.get_value(db, id_app, "codigos", "somos"))

        res = await AbonosService().obtener_precio(
            db=db,
            id_app=id_app,
            id_sede=id_sede,
            id_partner=id_partner,
            fecha_entrada=f"{arrival_date}",
            id_prod_det=id_prod_det,
            id_producto=id_producto,
            id_frecuencia=id_frecuencia,
            modified_by=user,
        )
        return {
            "priceId": res.get("token"),
            "price": int(float(res.get("precio")) * 100),  # en céntimos
            "precio_este_mes": int(
                float(res.get("precio_este_mes")) * 100
            ),  # en céntimos
            "iva": int(float(res.get("iva", 0)) * 100),  # en céntimos
            "tipo_iva": res.get("id_iva", 21),
            "entrada_real": res.get("entrada_real", None),
        }

    except HTTPException as e:
        raise e
    except Exception as e:
        print(traceback.format_exc())
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al consultar disponibilidad y precios: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
@router.post(
    "/abonos-create",
    response_model=CreateAbonoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un nuevo abono",
    description="Crea un nuevo abono para un cliente con las matrículas y configuración especificadas. Requiere autenticación JWT.",
)
async def create_abono(
    id_app: int,
    user: str,
    abono_data: CreateAbonoRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> CreateAbonoResponse:
    """
    Crear un nuevo abono.
    Requiere autenticación JWT.
    """
    try:
        abonos_service = AbonosService()
        # Convertir las fechas y horas a objetos datetime
        # fecha_entrada = abono_data.get_arrival_date()

        # Llamar al servicio para crear la reserva
        result = await abonos_service.crear_abono(
            db=db,
            id_app=id_app,
            user=user,
            priceToken=abono_data.priceToken,
            sedeId=abono_data.sedeId,
            channelId=abono_data.channelId,
            channel_Abono_code=abono_data.channel_Abono_code,
            matriculas=abono_data.matriculas,
            observaciones=abono_data.observaciones,
            clienteId=abono_data.clienteId,
            direccionId=abono_data.direccionId,
            direccion=abono_data.direccion,
            nombre=abono_data.nombre,
            apellido1=abono_data.apellido1,
            apellido2=abono_data.apellido2
            # ,id_tipo_documento = abono_data.id_tipo_documento
            # ,documento = abono_data.documento
            ,
            telefono=abono_data.telefono,
            fecha_no_ciclo=abono_data.fecha_no_ciclo,
        )

        # print(type(result), f"Sercivio de Abono creado correctamente: {result}")

        # Devolver la respuesta con los datos del abono creado
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el abono: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
@router.delete(
    "/abonos/{id_abono}",
    response_model=DeleteAbonoResponse,
    summary="Eliminar un abono",
    description="Elimina un abono existente dado su ID. Requiere autenticación JWT.",
)
async def delete_abono(
    id_abono: int = Path(..., description="ID del abono a eliminar"),
    id_app: int = Query(..., description="ID de la aplicación"),
    user: str = Query(..., description="Usuario que hace la petición"),
    fecha_real: str = Query(
        ..., description="Fecha real de baja del abono en formato YYYY-MM-DD"
    ),
    observaciones: Optional[str] = Query(
        None, description="Observaciones de la baja del abono"
    ),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> DeleteAbonoResponse:
    """
    Eliminar una reserva existente.
    Requiere autenticación JWT.
    """
    try:
        # Utilizar el servicio para eliminar la reserva
        abonos_service = AbonosService()
        result = await abonos_service.eliminar_abono(
            db,
            id_app=id_app,
            user=user,
            id_abono=id_abono,
            fecha_real=fecha_real,
            observaciones=observaciones,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el abono: {str(e)}",
        )


# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de ABONOS
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para la gestión de CLIENTES
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------


@router.post(
    "/clientes-create",
    response_model=CreateClienteResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un nuevo cliente",
    description="Crea un nuevo cliente en el sistema utilizando el SP cli_crea. Requiere autenticación JWT.",
)
async def create_cliente(
    cliente_data: CreateClienteRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> CreateClienteResponse:
    """
    Crear un nuevo cliente (usa SP `somos.cli_crea`). Requiere autenticación (igual que el resto de rutas backoffice).
    """
    try:
        service = ClientesCreateService()
        result = await service.crea_cliente(db=db, data=cliente_data)

        # Si el SP devuelve código de error lógico, devolvemos 409 para mantener coherencia
        if result.get("retNum") not in (None, 0):
            raise HTTPException(
                status_code=409, detail=result.get("retTxt") or "Operación no realizada"
            )

        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
@router.get(
    "/clientes-tantea-baja",
    response_model=TanteaBajaClienteResponse,
    status_code=status.HTTP_200_OK,
    summary="Tantear baja de cliente",
    description="Realiza comprobaciones previas para determinar si un cliente puede darse de baja y qué información mostrarle.",
)
async def clientes_tantea_baja(
    cliente_id: int = Query(..., description="ID del cliente a consultar"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    idApp: int = Query(None, description="ID de la aplicación"),
    user: str = Query(None, description="Usuario que realiza la consulta"),
) -> TanteaBajaClienteResponse:
    """
    Hace las comprobaciones pertinentes a un cliente para avisarle de la situación si se da de baja
    o de que no puede darse de baja por el motivo que sea
    """
    try:
        if not idApp:
            idApp = int(os.getenv("APP_ID"))
        if not user:
            user = int(os.getenv("USER_BACKOFFICE"))

        service = ClientesCreateService()
        result = await service.tantea_baja_cliente(
            db=db, cliente_id=cliente_id, idApp=idApp, user=user
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
@router.delete(
    "/clientes-baja",
    response_model=BajaClienteResponse,
    status_code=status.HTTP_200_OK,
    summary="Dar de baja un cliente",
    description="Da de baja un cliente del sistema. Requiere autenticación JWT.",
)
async def baja_cliente(
    idApp: int = Query(..., description="ID de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la operación"),
    cliente_id: int = Query(..., description="ID del cliente a dar de baja"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> BajaClienteResponse:
    """
    Da de baja un vehículo de un cliente
    """
    try:

        service = ClientesCreateService()
        result = await service.baja_cliente(
            db=db, idApp=idApp, user=user, cliente_id=cliente_id
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la baja del cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
@router.post(
    "/clientes-datos-facturacion",
    response_model=DatosFacturacionClienteResponse,
    status_code=status.HTTP_200_OK,
    summary="Gestionar datos de facturación de cliente",
    description="Crea o actualiza los datos de facturación de un cliente. Requiere autenticación JWT.",
)
async def datos_facturacion_clientes(
    cliente_id: int = Query(..., description="ID del cliente"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> DatosFacturacionClienteResponse:
    """
    Crea o actualiza los datos de facturación de un cliente.
    """
    result = None
    try:

        # service = ClientesCreateService()
        # result = await service.datos_facturacion_clientes(db=db, idApp=idApp, user=user, cliente_id=cliente_id)

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la creación/actualizacion de datos de facturación del cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de CLIENTES
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para la gestión de VEHICULOS de CLIENTES
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------


@router.post(
    "/clientes-vehiculos-alta",
    response_model=AltaVehiculoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Alta de vehículo de cliente",
    description="Da de alta un vehículo asociado a un cliente o lo modifica si ya existe (solo fecha hasta y situación).",
)
async def create_vehiculo(
    idApp: int,
    user: str,
    data: CreateVehiculoRequest,
    db: AsyncSession = Depends(get_db),
) -> VehiculoResponse:
    """
    Da de alta un vehículo de un cliente o lo modifica (solo para fecha hasta y situación)

        return {
            "code": Código 0 o negativo de error lógico,
            "detail": Texto con explicaciones,
            "id_vehiculo": nuevo ID creado para el vehículo,
        }

    """
    try:

        service = ClientesCreateService()
        result = await service.alta_cli_veh(db=db, idApp=idApp, user=user, data=data)

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la baja del vehiculo del cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
@router.put(
    "/clientes-vehiculos-mod/{vehiculo_id}",
    response_model=ModVehiculoResponse,
    status_code=status.HTTP_200_OK,
    summary="Modificar vehículo de cliente",
    description="Modifica un vehículo de un cliente (solo fecha hasta y estado). Requiere autenticación JWT.",
)
async def update_vehiculo(
    vehiculo_id: int = Path(..., description="ID del vehículo a modificar"),
    idApp: int = Query(..., description="ID de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la operación"),
    cliente_id: int = Query(..., description="ID del cliente propietario"),
    hasta: str = Query(None, description="Fecha hasta en formato YYYY-MM-DD HH:MM:SS"),
    estado: int = Query(None, description="Estado del vehículo (0=Activo, 1=Inactivo)"),
    alias: str = Query(..., description="alias del vehículo"),
    db: AsyncSession = Depends(get_db),
) -> ModVehiculoResponse:
    """
    Modificación de un vehículo de un cliente (solo para fecha hasta y estado)
    """
    try:

        service = ClientesCreateService()
        result = await service.mod_cli_veh(
            db=db,
            idApp=idApp,
            user=user,
            cliente_id=cliente_id,
            vehiculo_id=vehiculo_id,
            hasta=hasta,
            estado=estado,
            alias=alias,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la modificación del vehiculo del cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
@router.delete(
    "/clientes-vehiculos-baja",
    response_model=BajaVehiculoResponse,
    status_code=status.HTTP_200_OK,
    summary="Dar de baja un vehículo de cliente",
    description="Da de baja un vehículo asociado a un cliente. Requiere autenticación JWT.",
)
async def baja_cliente_vehiculo(
    idApp: int = Query(..., description="ID de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la operación"),
    cliente_id: int = Query(..., description="ID del cliente propietario"),
    vehiculo_id: int = Query(..., description="ID del vehículo a dar de baja"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> BajaVehiculoResponse:
    """
    Da de baja un vehículo de un cliente
    """
    try:

        service = ClientesCreateService()
        result = await service.baja_cliente_vehiculo(
            db=db,
            idApp=idApp,
            user=user,
            cliente_id=cliente_id,
            vehiculo_id=vehiculo_id,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la baja del vehiculo del cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de VEHICULOS de CLIENTES
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# Servicios para actuar sobre VEHICULOS de CLIENTES y PARTNERS
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------


@router.put(
    "/vehiculos-dentro-fuera",
    response_model=VehiculoDentroFueraResponse,
    status_code=status.HTTP_200_OK,
    summary="Registrar entrada/salida de vehículo",
    description="Registra la entrada o salida de un vehículo en un aparcamiento. Requiere autenticación JWT.",
)
async def vehiculos_dentro_fuera(
    idApp: int = Query(..., description="ID de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la operación"),
    origen: str = Query(..., description="Origen del movimiento"),
    id_veh_mov: int = Query(..., description="ID del movimiento de vehículo"),
    fecha_hora: str = Query(..., description="Fecha y hora del movimiento"),
    matricula: str = Query(..., description="Matrícula del vehículo"),
    situacion: str = Query(
        ..., description="Situación del vehículo (D=Dentro, F=Fuera)"
    ),
    precio: float = Query(..., description="Precio del movimiento"),
    observaciones: str = Query(..., description="Observaciones del movimiento"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> VehiculoDentroFueraResponse:
    """
    Saca o mete a un vehículo en un aparcamiento.
    """
    try:
        # Validación: matrícula obligatoria y no vacía
        if not matricula or not str(matricula).strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La matrícula del vehículo es obligatoria y no puede estar vacía",
            )

        service = VehiculosServiceRequest()
        result = await service.veh_dentro_fuera(
            db=db,
            idApp=idApp,
            user=user,
            origen=origen,
            id_veh_mov=id_veh_mov,
            fecha_hora=fecha_hora,
            matricula=matricula,
            situacion=situacion,
            precio=precio,
            observaciones=observaciones,
        )

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la baja del vehiculo del cliente: {e}",
        )


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# FIN Servicios para la gestión de VEHICULOS de CLIENTES y PARTNERS
# -------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para actuar sobre SISTEMAS DE CONTROL
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.post(
    "/barrera",
    status_code=status.HTTP_201_CREATED,
    response_model=BarreraResponse,
    summary="Acción sobre barrera (abrir/cerrar/estado)",
    description="Realiza una acción sobre la barrera del parking: A (abrir), C (cerrar), S (consultar estado). "
    "El ID de máquina se construye con la constante (5 para entrada, 6 para salida) y el número de máquina. "
    "Por ejemplo, 501 sería entrada 1. Requiere autenticación.",
)
async def barrera(
    datos: BarrerasRequest, request: Request, db: AsyncSession = Depends(get_db)
) -> BarreraResponse:
    """
    ID de máquina, que se construye con la constante (5 para entrada, 6 para salida) y el número de máquina. Por ejemplo, 501 sería entrada 1
    Retorna el estado de una barrera.
            {
                "status_code": 0,
                "status_description": "CERRADA",
                "loop_detection": false,
                "operation_in_progress": false
            }

    Requiere autenticación (igual que el resto de rutas backoffice).
    """
    try:
        # service = ClientesCreateService()
        # result = await service.crear_cliente(db=db, data=cliente_data)

        service = BarrerasService()
        result = await service.accion(db=db, data=datos)

        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error evaluando {datos.sdc}-{datos.parking}-{datos.tipo}-{datos.token_maquina}-{datos.id_tipo}-{datos.id_local_num}-{datos.accion}: {e}",
        )


# -------------------------------------------------------------------------------------------------

"""
Creo que no se utilida este endpoint, habría que revisar si se puede eliminar o si hay que implementarlo en el servicio correspondiente. De momento lo dejo comentado para no perder la referencia al mismo.
@router.post("/cierre-manual-barrera",
    response_model=CierreManualBarreraResponse,
    summary="Cierre manual de barrera",
    description="Autoriza la salida de un vehículo mediante cierre manual de barrera. "
    "Se utiliza cuando el operador necesita realizar un cierre manual indicando "
    "matrícula, importe y observaciones.",
)
async def cierre_manual_barrera(
    id_usuario: int = Query(..., description="Identificador del usuario que realiza el cierre"),
    id_aparcamiento: str = Query(..., description="Identificador del aparcamiento"),
    tipo_aparato: str = Query(..., description="Identificador del vial por donde accede el usuario"),
    numero_aparato: int = Query(..., description="Número de vial por donde accede el usuario"),
    fecha_hora: datetime = Query(..., description="Fecha y hora local en formato ISO-8601"),
    fecha_hora_entrada: Optional[datetime] = Query(None, description="Fecha y hora local de entrada en formato ISO-8601"),
    numeroSerieContactless: Optional[str] = Query(None, description="Nº de serie de la tarjeta contactless"),
    codigoBarras: Optional[str] = Query(None, description="Código de barras escaneado"),
    matricula: str = Query(..., description="Matrícula reconocida"),
    importe_a_pagar: float = Query(..., description="Importe a pagar asociado al usuario"),
    observaciones: Optional[str] = Query(None, description="Observaciones del cierre manual"),
    foto: Optional[str] = Query(None, description="Foto en base64"),
    db: Session = Depends(get_db),
) -> CierreManualBarreraResponse:
    try:
        service = BarrerasAutorizacionService()

        id_app = int(os.getenv("APP_ID"))
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
            "id_usuario": id_usuario,
            "matricula": matricula,
            "numeroSerieContactless": numeroSerieContactless,
            "codigoBarras": codigoBarras,
            "importe_a_pagar": importe_a_pagar,
            "cierre_manual": True,
            "observaciones": observaciones,
            "foto": foto,
            "fecha_entrada": fecha_hora_entrada.strftime("%Y-%m-%d %H:%M:%S"),
        }

        result = await service.autorizar_salida(
            db=db,
            id_app=id_app,
            id_sdc=id_sdc,
            codigo_parking=id_aparcamiento,
            tipo_aparato=tipo_aparato,
            numero_aparato=numero_aparato,
            fecha_hora=fecha_hora,
            datos=json.dumps(datos_salida),
            license_plate=matricula,
            importe_a_pagar=importe_a_pagar,
            cierre_manual=True,
            id_usuario=id_usuario,
            observaciones=observaciones,
            foto=foto,
            fecha_hora_entrada=fecha_hora_entrada,
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
"""

# -------------------------------------------------------------------------------------------------
# FIN Servicios para actuar sobre SISTEMAS DE CONTROL
# -------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
# Servicios para actuar sobre el DATA
# -------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------
@router.get(
    "/caja-aparcamiento-dia",
    status_code=status.HTTP_200_OK,
    response_model=List[FacAparcamientoDiaItem],
    summary="Datos de facturación de aparcamiento por día",
    description="Retorna datos para poder hacer la facturación de un aparcamiento de un día determinado. "
    "Devuelve un array con la información de facturación del día solicitado.",
)
async def caja_aparcamiento_dia(
    id_app: int = Query(..., description="Identificador de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la consulta"),
    dia: str = Query(..., description="Fecha en formato YYYY-MM-DD"),
    acronimo: str = Query(..., description="Acrónimo del aparcamiento"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> List[FacAparcamientoDiaItem]:
    """
    Retorna datos para poder hacer la facturación de un aparcamiento de un día determinado.
    """
    try:
        service = RompetechosServiceRquest()
        result = await service.caja_aparcamiento_dia(
            db=db, id_app=id_app, user=user, dia=dia, acronimo=acronimo
        )
        # print('***************************************************************')
        # print('fac-aparcamiento-dia: ', dia, acronimo, result, type(result))
        # print('***************************************************************')

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la Retorna datos para poder hacer la factura de un aparcamiento de un día determinado: {e}",
        )


# -------------------------------------------------------------------------------------------------


@router.get(
    "/caja-de-ticket-apk",
    status_code=status.HTTP_200_OK,
    response_model=List[FacTicketApkItem],
    summary="Datos de facturación de un ticket específico",
    description="Retorna datos de un ticket concreto para facturación. "
    "Si se encuentran varios tickets coincidentes, retorna los valores de todos.",
)
async def caja_de_ticket_apk(
    id_app: int = Query(..., description="Identificador de la aplicación"),
    user: str = Query(..., description="Usuario que realiza la consulta"),
    dia: str = Query(..., description="Fecha en formato YYYY-MM-DD"),
    acronimo: str = Query(..., description="Acrónimo del aparcamiento"),
    cardNo: str = Query(..., description="Número de tarjeta o ticket"),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
) -> List[FacTicketApkItem]:
    """
    Retorna datos para poder hacer la facturación de un aparcamiento de un día determinado.
    """
    try:
        service = RompetechosServiceRquest()
        result = await service.caja_de_ticket_apk(
            db=db, id_app=id_app, user=user, dia=dia, acronimo=acronimo, cardNo=cardNo
        )
        # print('***************************************************************')
        # print('fac-de-ticket-apk: ', dia, acronimo, result, type(result))
        # print('***************************************************************')

        return JSONResponse(status_code=status.HTTP_200_OK, content=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la Retorna datos para poder hacer la factura de caja de un ticket determinado: {e}",
        )


# -------------------------------------------------------------------------------------------------
# FIN Servicios para actuar sobre el DATA
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# Servicio para enviar mensajes HTML a terminales
# -------------------------------------------------------------------------------------------------
@router.post(
    "/send-html-message",
    status_code=status.HTTP_200_OK,
    summary="Enviar mensaje HTML a un terminal",
    description="Envía un mensaje HTML a un terminal específico. Puede ser un mensaje predefinido o personalizado.",
)
async def send_html_message(
    data: SendHtmlMessageRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """
    Envía un mensaje HTML a un terminal (raspberry).
    """
    try:
        if data.tipo_mensaje not in ("custom", "default"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Tipo de mensaje '{data.tipo_mensaje}' no válido. Use 'default' o 'custom'.",
            )

        if data.tipo_mensaje == "custom" and not data.duracion:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Es necesario especificar la duración del mensaje para mensajes personalizados.",
            )

        raspberry_service = RaspberryService(db=db, message_type=data.tipo_mensaje)
        await raspberry_service.send_html(data.terminal, data.mensaje, data.duracion)

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "message": "Mensaje enviado correctamente al terminal",
                "terminal": data.terminal,
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al enviar mensaje HTML al terminal: {e}",
        )


# -------------------------------------------------------------------------------------------------
# FIN Servicios para enviar mensajes HTML a terminales
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# Servicio para FACTURACION
# -------------------------------------------------------------------------------------------------
from app.config.db import get_db_manager
from app.services.facService import FacService

@router.post(
    "/synchronize-sap",
    status_code=status.HTTP_200_OK,
    summary="Sincronizar facturas con SAP",
    description="Lanza el mismo proceso que el script scripts/crontabs/syncronize_sap.py para sincronizar facturas pendientes con SAP.",
)
async def synchronize_sap(
    max_facs: int = Query( -1 ,description="Número máximo de facturas a procesar. -1 significa sin límite.",),
    user: str = Query(..., description="Usuario que realiza la operación",),
) -> dict:
    """
    Ejecuta la sincronización de facturas pendientes con SAP.
    """
    try:
        db_manager = get_db_manager()

        with db_manager.get_session() as session:
            service = FacService(db=session)
            ret = await service.synchronize_with_sap(max_facs=max_facs, usuario=user)

        if not isinstance(ret, dict):
            ret = {}

        return {
            "message": "Sincronización con SAP finalizada correctamente",
            "max_facs": max_facs,
            **ret,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error durante la sincronización con SAP: {str(e)}",
        )
# -------------------------------------------------------------------------------------------------
# FIN Servicio para FACTURACION
# -------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------
# Colaboradores — Carga de saldo
# -------------------------------------------------------------------------------------------------

@router.post(
    "/colaboradores/carga-saldo",
    response_model=CargaSaldoColaboradorResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cargar saldo a un colaborador",
    description=(
        "Persiste la operación de carga de saldo en BBDD mediante `w_col_carga_saldo` "
        "e inicia el proceso de pago con Paycomet. "
        "Devuelve la URL de pago y los datos del registro creado."
    ),
)
async def bo_carga_saldo_colaborador(
    datos: CargaSaldoColaboradorRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> CargaSaldoColaboradorResponse:
    """Carga de saldo para colaboradores prepago. Requiere autenticación JWT."""

    try:
        servicio = CargaSaldoColaboradorService()
        result = await servicio.carga_saldo(db=db, request=request, datos=datos)
        return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al procesar la carga de saldo: {str(e)}",
        )

# -------------------------------------------------------------------------------------------------
# FIN Colaboradores — Carga de saldo
# -------------------------------------------------------------------------------------------------
