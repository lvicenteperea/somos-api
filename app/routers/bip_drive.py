from fastapi import APIRouter, status, HTTPException, Depends
from fastapi.responses import JSONResponse
from sqlmodel import Session
from app.schemas.bip_drive import (
    BipDriveLicensePlatesRequest,
    AddLicensePlatesResponse,
    RemoveLicensePlatesResponse,
)
from app.services.matriculas import MatriculasService
from app.config.db import get_db
from app.models.mat_matricula import SistemaEnum
from datetime import date

router = APIRouter(prefix="/bip-drive", tags=["bip_drive"])


@router.post(
    "/licensePlate/addlicenseplates",
    response_model=AddLicensePlatesResponse,
    summary="Dar de alta matrículas",
    description="Da de alta un listado de matrículas en el sistema. Procesa cada matrícula individualmente y devuelve un resumen con las exitosas y fallidas.",
)
async def add_license_plates(
    request: BipDriveLicensePlatesRequest, db: Session = Depends(get_db)
) -> AddLicensePlatesResponse:
    """
    Endpoint para dar de alta un listado de matrículas.

    Args:
        request: Objeto que contiene el array de matrículas en el campo 'lp'
        db: Sesión de base de datos

    Returns:
        JSONResponse con status 200 si todo va bien

    Raises:
        HTTPException 400 si el parámetro 'lp' está vacío o no viene
    """
    try:
        # Validar que el array lp no esté vacío
        if not request.lp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El parámetro 'lp' no puede estar vacío",
            )

        # Validar que todos los elementos del array sean strings no vacíos
        for i, license_plate in enumerate(request.lp):
            if not license_plate or not license_plate.strip():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"La matrícula en la posición {i} no puede estar vacía",
                )

        # Crear instancia del servicio de matrículas
        matriculas_service = MatriculasService()

        # Parámetros fijos para BipDrive (ajustar según configuración)
        id_app = 1  # TODO: Obtener de configuración o contexto
        id_partner = 3  # TODO: Obtener de configuración o contexto de autenticación
        fecha_desde = date.today()  # Fecha actual como inicio de validez

        # Variables para el resultado
        total_procesadas = len(request.lp)
        exitosas = 0
        fallidas = 0
        errores = []
        resultados_exitosos = []

        # Recorrer todas las matrículas y procesarlas una por una
        for i, matricula in enumerate(request.lp):
            try:
                # Insertar la matrícula individual usando el servicio
                resultado = await matriculas_service.insertar_matricula(
                    db=db,
                    matricula=matricula.strip(),
                    id_app=id_app,
                    id_partner=id_partner,
                    fecha_desde=fecha_desde,
                    sistema=SistemaEnum.ROTACION.value,  # Usar el valor del enum directamente
                    modified_by="bip_drive_api",
                )

                # Si la inserción fue exitosa
                exitosas += 1
                resultados_exitosos.append(
                    {
                        "index": i,
                        "matricula": matricula,
                        "id": resultado["data"]["id"],
                        "numero": resultado["data"]["numero"],
                    }
                )

            except HTTPException as e:
                # Capturar errores HTTP específicos (ej: matrícula duplicada)
                fallidas += 1
                errores.append({"index": i, "matricula": matricula, "error": e.detail})

            except Exception as e:
                # Capturar cualquier otro error
                fallidas += 1
                errores.append({"index": i, "matricula": matricula, "error": str(e)})

        # Registrar en logs para monitoreo
        print(f"Matrículas procesadas: {total_procesadas}")
        print(f"Exitosas: {exitosas}, Fallidas: {fallidas}")

        # Preparar respuesta
        response_content = {
            "processed": total_procesadas,
            "successful": exitosas,
            "failed": fallidas,
        }

        # Solo incluir detalles de errores si los hay
        if errores:
            response_content["errors"] = errores

        # Solo incluir resultados exitosos si los hay
        if resultados_exitosos:
            response_content["successful_results"] = resultados_exitosos

        return JSONResponse(status_code=status.HTTP_200_OK, content=response_content)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno del servidor: {str(e)}",
        )


@router.post(
    "/licensePlate/removelicenseplates",
    response_model=RemoveLicensePlatesResponse,
    summary="Dar de baja matrículas",
    description="Da de baja un listado de matrículas en el sistema. Procesa cada matrícula individualmente y devuelve un resumen con las exitosas y fallidas.",
)
async def remove_license_plates(
    request: BipDriveLicensePlatesRequest, db: Session = Depends(get_db)
) -> RemoveLicensePlatesResponse:
    """
    Endpoint para dar de baja un listado de matrículas.

    Args:
        request: Objeto que contiene el array de matrículas en el campo 'lp'
        db: Sesión de base de datos

    Returns:
        JSONResponse con status 200 si todo va bien

    Raises:
        HTTPException 400 si el parámetro 'lp' está vacío o no viene
    """
    try:
        # Validar que el array lp no esté vacío
        if not request.lp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El parámetro 'lp' no puede estar vacío",
            )

        # Validar que todos los elementos del array sean strings no vacíos
        for i, license_plate in enumerate(request.lp):
            if not license_plate or not license_plate.strip():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"La matrícula en la posición {i} no puede estar vacía",
                )

        # Crear instancia del servicio de matrículas
        matriculas_service = MatriculasService()

        # Parámetros fijos para BipDrive (ajustar según configuración)
        id_app = 1  # TODO: Obtener de configuración o contexto
        id_partner = 3  # TODO: Obtener de configuración o contexto de autenticación

        # Variables para el resultado
        total_procesadas = len(request.lp)
        exitosas = 0
        fallidas = 0
        errores = []
        resultados_exitosos = []

        # Recorrer todas las matrículas y procesarlas una por una
        for i, matricula in enumerate(request.lp):
            try:
                # Desactivar la matrícula individual usando el servicio
                resultado = await matriculas_service.desactivar_matricula(
                    db=db,
                    matricula=matricula.strip(),
                    id_app=id_app,
                    id_partner=id_partner,
                    modified_by="bip_drive_api",
                )

                # Si la desactivación fue exitosa
                exitosas += 1
                resultados_exitosos.append(
                    {
                        "index": i,
                        "matricula": matricula,
                        "id": resultado["data"]["id"],
                        "fecha_hasta": resultado["data"]["fecha_hasta"],
                    }
                )

            except HTTPException as e:
                # Capturar errores HTTP específicos (ej: matrícula no encontrada)
                fallidas += 1
                errores.append({"index": i, "matricula": matricula, "error": e.detail})

            except Exception as e:
                # Capturar cualquier otro error
                fallidas += 1
                errores.append({"index": i, "matricula": matricula, "error": str(e)})

        # Registrar en logs para monitoreo
        print(f"Matrículas procesadas para desactivación: {total_procesadas}")
        print(f"Exitosas: {exitosas}, Fallidas: {fallidas}")

        # Preparar respuesta
        response_content = {
            "processed": total_procesadas,
            "successful": exitosas,
            "failed": fallidas,
        }

        # Solo incluir detalles de errores si los hay
        if errores:
            response_content["errors"] = errores

        # Solo incluir resultados exitosos si los hay
        if resultados_exitosos:
            response_content["successful_results"] = resultados_exitosos

        return JSONResponse(status_code=status.HTTP_200_OK, content=response_content)

    except HTTPException as e:
        # Re-lanzar excepciones HTTP para mantener el código de estado
        raise e
    except Exception as e:
        # Capturar cualquier error durante la ejecución
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno del servidor: {str(e)}",
        )
