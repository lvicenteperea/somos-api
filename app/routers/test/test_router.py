from fastapi import APIRouter, status, HTTPException, Request, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.config.db import get_db
from pydantic import BaseModel
from typing import List

from app.providers.equinsa.generales import EquinsaGenerales
from app.utils.auth import get_password_hash
# from app.services.contadores import ContadoresService
router = APIRouter(prefix="/test", tags=["test"])

@router.get("/equinsa")
async def equinsa():
    equinsa_reservas = EquinsaGenerales(1067)

    # Llamar a la función edit_reservation del provider de equinsa
    equinsa_response = await equinsa_reservas.system_version()

    return {equinsa_response}



@router.get("/auth")
async def equinsa():
    return {get_password_hash("mS92KtzQQ5WTrrJrKFrM")}



# class ContadoresRequest(BaseModel):
#     apk: List[str] = ""   # nemotécnico del aparcamiento en somos

# @router.get("/contadores", status_code=status.HTTP_201_CREATED)
# async def equisa(contadores_data: ContadoresRequest, request: Request, db: AsyncSession = Depends(get_db)):
#     """
#     Ver contadores de un aparcamiento.
#     Requiere autenticación JWT.
#     """
#     try:
#         contadores_service = ContadoresService()

#         # Llamar al servicio para crear la reserva
#         result = await contadores_service.contadores(db = db
#                                                    ,canal = "BO"
#                                                    ,apk = contadores_data.apk)
        
#         # Devolver la respuesta con los datos de la reserva creada
#         return JSONResponse(status_code=status.HTTP_201_CREATED, content=result)
        
#     except HTTPException as e:
#         # Re-lanzar excepciones HTTP para mantener el código de estado
#         raise e
#     except Exception as e:
#         # Capturar cualquier error durante la ejecución
#         raise HTTPException(
#             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
#             detail=f"Error servicio contadores: {str(e)}"
#         )
