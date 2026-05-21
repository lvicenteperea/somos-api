from fastapi import APIRouter, status, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List, Optional
from app.providers.letmepark.letmepark import LetMePark


class Credential(BaseModel):
    """
    Modelo para las credenciales de acceso.
    """
    type: str  # "plate" o "barcode"
    number: str


class ValidateRequest(BaseModel):
    """
    Modelo para los datos requeridos para validar un acceso en LetMePark.
    """
    date: str  # Fecha en UTC en formato ISO-8601
    access_direction: int  # 1 -> Entrada; 2 -> Salida
    credentials: List[Credential]
    id_parking: str


class RegisterRequest(BaseModel):
    """
    Modelo para los datos requeridos para registrar un acceso en LetMePark.
    """
    date: str  # Fecha en UTC en formato ISO-8601
    direction: int  # 1 -> Entrada; 2 -> Salida
    credentials: List[Credential]
    id_parking: str
    price: Optional[float] = None  # Solo para salidas


router = APIRouter(prefix="/test/letmepark", tags=["test-letmepark"])


@router.post("/validate", status_code=status.HTTP_200_OK)
async def test_letmepark_validate(request_data: ValidateRequest):
    """
    Prueba la función de validate del provider LetMePark.
    
    Endpoint para probar la validación de accesos en LetMePark.
    Valida si un vehículo puede entrar o salir del parking.
    
    Args:
        request_data: Datos requeridos para la validación del acceso
        
    Returns:
        JSON con la respuesta de la validación o error en caso de fallo
    """
    letmepark_client = None

    try:
        # Crear una instancia del provider LetMePark
        letmepark_client = LetMePark()

        # Convertir las credenciales de Pydantic a dict
        credentials_dict = [
            {"type": cred.type, "number": cred.number}
            for cred in request_data.credentials
        ]

        # Llamar a la función de validate
        validate_response = await letmepark_client.validate(
            date=request_data.date,
            access_direction=request_data.access_direction,
            credentials=credentials_dict,
            id_parking=request_data.id_parking
        )

        # Devolver respuesta exitosa con los datos de la validación
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Validación exitosa en LetMePark",
                "data": validate_response
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
            detail=f"Error en validate de LetMePark: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if letmepark_client:
            try:
                await letmepark_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente LetMePark: {str(e)}")


@router.post("/register", status_code=status.HTTP_200_OK)
async def test_letmepark_register(request_data: RegisterRequest):
    """
    Prueba la función de register del provider LetMePark.
    
    Endpoint para probar el registro de accesos en LetMePark.
    Registra un acceso que fue previamente validado.
    
    Args:
        request_data: Datos requeridos para el registro del acceso
        
    Returns:
        JSON con la respuesta del registro o error en caso de fallo
    """
    letmepark_client = None

    try:
        # Crear una instancia del provider LetMePark
        letmepark_client = LetMePark()

        # Convertir las credenciales de Pydantic a dict
        credentials_dict = [
            {"type": cred.type, "number": cred.number}
            for cred in request_data.credentials
        ]

        # Llamar a la función de register
        register_response = await letmepark_client.register(
            date=request_data.date,
            direction=request_data.direction,
            credentials=credentials_dict,
            id_parking=request_data.id_parking,
            price=request_data.price
        )

        # Devolver respuesta exitosa con los datos del registro
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Registro exitoso en LetMePark",
                "data": register_response
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
            detail=f"Error en register de LetMePark: {str(e)}"
        )

    finally:
        # Asegurar que se cierre la conexión del cliente
        if letmepark_client:
            try:
                await letmepark_client.close()
            except Exception as e:
                print(f"Warning: Error al cerrar cliente LetMePark: {str(e)}")
