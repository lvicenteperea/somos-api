from fastapi import APIRouter, status, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from app.providers.easypark.easypark import EasyPark


class AutomaticStartRequest(BaseModel):
    """
    Modelo para los datos requeridos para el inicio automático de estacionamiento.
    """
    external_parking_id: str
    parking_operator_id: str
    area_no: str
    parking_operator_area_no: str
    area_country_code: str
    license_number: str
    start_date: str
    car_country_code: str


class AutomaticStopRequest(BaseModel):
    """
    Modelo para los datos requeridos para la detención automática de estacionamiento.
    """
    external_parking_id: str
    parking_operator_id: str
    area_no: str
    parking_operator_area_no: str
    area_country_code: str
    license_number: str
    start_date: str
    end_date: str
    car_country_code: str
    parking_fee: float


class AutomaticCheckRequest(BaseModel):
    """
    Modelo para los datos requeridos para la verificación de estacionamiento.
    """
    external_parking_id: str
    parking_operator_id: str
    area_no: str
    parking_operator_area_no: str
    area_country_code: str
    license_number: str
    start_date: str
    car_country_code: str


router = APIRouter(prefix="/test/easypark", tags=["test-easypark"])


@router.get("/login", status_code=status.HTTP_200_OK)
async def test_easypark_login():
    """
    Prueba la función de login del provider EasyPark.
    
    Endpoint para probar la conexión y autenticación con la API de EasyPark
    desde un cliente de API (Postman, curl, etc.).
    
    Returns:
        JSON con la respuesta del login de EasyPark o error en caso de fallo
    """
    easypark_client = None

    try:
        # Crear una instancia del provider EasyPark
        easypark_client = EasyPark()

        # Llamar a la función de login
        login_response = await easypark_client.login()

        # Devolver respuesta exitosa con los datos del login
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Login exitoso en EasyPark",
                "data": login_response
            }
        )

    except ValueError as ve:
        # Error de configuración (variables de entorno faltantes)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error de configuración: {str(ve)}"
        )

    except HTTPException as he:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise he

    except Exception as e:
        # Capturar cualquier otro error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al conectar con EasyPark: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if easypark_client:
            try:
                await easypark_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente EasyPark: {str(e)}")


@router.post("/automatic-start", status_code=status.HTTP_200_OK)
async def test_easypark_automatic_start(request_data: AutomaticStartRequest):
    """
    Prueba la función de automatic_start del provider EasyPark.
    
    Endpoint para probar el inicio automático de estacionamiento que incluye:
    1. Login automático para obtener el idToken
    2. Llamada al endpoint /gated/external/parkings/start con los datos proporcionados
    
    Args:
        request_data: Datos requeridos para el inicio de estacionamiento
        
    Returns:
        JSON con la respuesta del inicio automático o error en caso de fallo
    """
    easypark_client = None

    try:
        # Crear una instancia del provider EasyPark
        easypark_client = EasyPark()

        # Llamar a la función de automatic_start
        start_response = await easypark_client.automatic_start(
            external_parking_id=request_data.external_parking_id,
            parking_operator_id=request_data.parking_operator_id,
            area_no=request_data.area_no,
            parking_operator_area_no=request_data.parking_operator_area_no,
            area_country_code=request_data.area_country_code,
            license_number=request_data.license_number,
            start_date=request_data.start_date,
            car_country_code=request_data.car_country_code
        )

        # Devolver respuesta exitosa con los datos del inicio
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Inicio automático exitoso en EasyPark",
                "data": start_response
            }
        )

    except ValueError as ve:
        # Error de configuración (variables de entorno faltantes)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error de configuración: {str(ve)}"
        )

    except HTTPException as he:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise he

    except Exception as e:
        # Capturar cualquier otro error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en automatic_start de EasyPark: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if easypark_client:
            try:
                await easypark_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente EasyPark: {str(e)}")


@router.post("/automatic-stop", status_code=status.HTTP_200_OK)
async def test_easypark_automatic_stop(request_data: AutomaticStopRequest):
    """
    Prueba la función de automatic_stop del provider EasyPark.
    
    Endpoint para probar la detención automática de estacionamiento que incluye:
    1. Login automático para obtener el idToken
    2. Llamada al endpoint /gated/external/parkings/stop con los datos proporcionados
    
    Args:
        request_data: Datos requeridos para la detención de estacionamiento
        
    Returns:
        JSON con la respuesta de la detención automática o error en caso de fallo
    """
    easypark_client = None

    try:
        # Crear una instancia del provider EasyPark
        easypark_client = EasyPark()

        # Llamar a la función de automatic_stop
        stop_response = await easypark_client.automatic_stop(
            external_parking_id=request_data.external_parking_id,
            parking_operator_id=request_data.parking_operator_id,
            area_no=request_data.area_no,
            parking_operator_area_no=request_data.parking_operator_area_no,
            area_country_code=request_data.area_country_code,
            license_number=request_data.license_number,
            start_date=request_data.start_date,
            end_date=request_data.end_date,
            car_country_code=request_data.car_country_code,
            parking_fee=request_data.parking_fee
        )

        # Devolver respuesta exitosa con los datos de la detención
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Detención automática exitosa en EasyPark",
                "data": stop_response
            }
        )

    except ValueError as ve:
        # Error de configuración (variables de entorno faltantes)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error de configuración: {str(ve)}"
        )

    except HTTPException as he:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise he

    except Exception as e:
        # Capturar cualquier otro error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en automatic_stop de EasyPark: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if easypark_client:
            try:
                await easypark_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente EasyPark: {str(e)}")


@router.post("/automatic-check", status_code=status.HTTP_200_OK)
async def test_easypark_automatic_check(request_data: AutomaticCheckRequest):
    """
    Prueba la función de automatic_check del provider EasyPark.
    
    Endpoint para probar la verificación de estacionamiento que incluye:
    1. Login automático para obtener el idToken
    2. Llamada al endpoint /gated/external/parkings/check con los datos proporcionados
    
    Args:
        request_data: Datos requeridos para la verificación de estacionamiento
        
    Returns:
        JSON con la respuesta de la verificación o error en caso de fallo
    """
    easypark_client = None

    try:
        # Crear una instancia del provider EasyPark
        easypark_client = EasyPark()

        # Llamar a la función de automatic_check
        check_response = await easypark_client.automatic_check(
            external_parking_id=request_data.external_parking_id,
            parking_operator_id=request_data.parking_operator_id,
            area_no=request_data.area_no,
            parking_operator_area_no=request_data.parking_operator_area_no,
            area_country_code=request_data.area_country_code,
            license_number=request_data.license_number,
            start_date=request_data.start_date,
            car_country_code=request_data.car_country_code
        )

        # Devolver respuesta exitosa con los datos de la verificación
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Verificación exitosa en EasyPark",
                "data": check_response
            }
        )

    except ValueError as ve:
        # Error de configuración (variables de entorno faltantes)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error de configuración: {str(ve)}"
        )

    except HTTPException as he:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise he

    except Exception as e:
        # Capturar cualquier otro error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en automatic_check de EasyPark: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if easypark_client:
            try:
                await easypark_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente EasyPark: {str(e)}")
