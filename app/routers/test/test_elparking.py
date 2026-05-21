from fastapi import APIRouter, status, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
from app.providers.elparking.rotacion import RotacionElParking


class AccessAuthorizationRequest(BaseModel):
    """
    Modelo para los datos requeridos para solicitar autorización de acceso.
    """
    license_plate: str
    lane_id: str
    truck_trailer_number_plate: Optional[str] = None
    vehicle_type: Optional[str] = None
    vehicle_weight: Optional[float] = None


router = APIRouter(prefix="/test/elparking", tags=["test-elparking"])


@router.post("/request-access-authorization", status_code=status.HTTP_200_OK)
async def test_elparking_request_access_authorization(request_data: AccessAuthorizationRequest):
    """
    Prueba la función de request_access_authorization del provider ElParking.
    
    Endpoint para probar la solicitud de autorización de acceso al parking que incluye:
    1. Autenticación básica con usuario:contraseña en base64
    2. Llamada GET al endpoint /authorization con los parámetros proporcionados
    
    Args:
        request_data: Datos requeridos para la autorización de acceso
        
    Returns:
        JSON con la respuesta de la autorización de acceso o error en caso de fallo
    """
    elparking_client = None

    try:
        # Crear una instancia del provider ElParking con el carpark_id
        elparking_client = RotacionElParking()

        # Llamar a la función de request_access_authorization
        authorization_response = await elparking_client.request_access_authorization(
            license_plate=request_data.license_plate,
            lane_id=request_data.lane_id,
            truck_trailer_number_plate=request_data.truck_trailer_number_plate,
            vehicle_type=request_data.vehicle_type,
            vehicle_weight=request_data.vehicle_weight
        )

        # Devolver respuesta exitosa con los datos de la autorización
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Solicitud de autorización de acceso exitosa en ElParking",
                "status_code": authorization_response.status_code,
                "headers": dict(authorization_response.headers),
                "data": authorization_response.json() if authorization_response.headers.get("content-type", "").startswith("application/json") else authorization_response.text
            }
        )

    except ValueError as ve:
        # Error de validación de parámetros o configuración
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error de validación: {str(ve)}"
        )

    except HTTPException as he:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise he

    except Exception as e:
        # Capturar cualquier otro error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al solicitar autorización de acceso en ElParking: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if elparking_client:
            try:
                await elparking_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente ElParking: {str(e)}")


@router.get("/health-check", status_code=status.HTTP_200_OK)
async def test_elparking_health_check():
    """
    Endpoint de verificación de salud para ElParking.
    
    Verifica que las credenciales estén configuradas correctamente
    sin realizar ninguna llamada a la API externa.
    
    Returns:
        JSON con el estado de configuración de ElParking
    """
    try:
        # Intentar crear una instancia con un carpark_id de prueba
        elparking_client = RotacionElParking(carpark_id=1)
        
        # Si llegamos aquí, las credenciales están configuradas
        await elparking_client.close()
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "ElParking provider configurado correctamente",
                "provider": "ElParking",
                "credentials_configured": True
            }
        )

    except HTTPException as he:
        # Error de configuración (credenciales faltantes)
        return JSONResponse(
            status_code=he.status_code,
            content={
                "status": "error",
                "message": he.detail,
                "provider": "ElParking",
                "credentials_configured": False
            }
        )

    except Exception as e:
        # Cualquier otro error
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error inesperado al verificar configuración de ElParking: {str(e)}"
        )
