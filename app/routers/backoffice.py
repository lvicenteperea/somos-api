from datetime import datetime
from decimal import Decimal, InvalidOperation

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse
from sqlmodel import Session

from app.config.db import get_db
from app.config.settings import settings
from app.schemas.auth import AuthResponse, LoginRequest
from app.schemas.tickets import TicketValidaResponse
from app.services.tickets import TicketsService
from app.utils.auth import get_jwt_token

router = APIRouter(prefix="/bo", tags=["bo"])

MAX_TICKET_IMPORTE = Decimal("99999999.99")


@router.post(
    "/auth",
    response_model=AuthResponse,
    summary="Autenticacion de usuario",
    description="Autentica al usuario con sus credenciales y devuelve un token JWT.",
)
async def login(login_data: LoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    token_data = await get_jwt_token(
        db,
        login_data.username,
        login_data.password,
        settings.SOMOS_SLUG,
    )

    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username or password incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return JSONResponse(status_code=status.HTTP_200_OK, content=token_data)


@router.post(
    "/ticket/valida",
    response_model=TicketValidaResponse,
    summary="Validar ticket",
    description="Valida un ticket de campana y devuelve el cupon obtenido.",
)
async def validar_ticket_handler(
    user: str = Form(..., min_length=1),
    imagen: UploadFile = File(...),
    id_campana: int = Form(..., ge=1),
    numero_ticket: str = Form(..., min_length=1),
    fecha: datetime = Form(...),
    importe: Decimal = Form(...),
    id_app: int = Form(settings.APP_ID, ge=1),
    db: Session = Depends(get_db),
) -> TicketValidaResponse:
    importe_validado = _validate_ticket_importe(importe)

    response = await TicketsService().validar_ticket(
        db=db,
        id_app=id_app,
        user=user,
        imagen=imagen,
        id_campana=id_campana,
        numero_ticket=numero_ticket,
        fecha_ticket=fecha,
        importe=importe_validado,
    )

    return JSONResponse(status_code=status.HTTP_200_OK, content=response.model_dump())


def _validate_ticket_importe(importe: Decimal) -> Decimal:
    if not importe.is_finite():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El importe no es valido",
        )

    if importe.as_tuple().exponent < -2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El importe debe tener como maximo dos decimales",
        )

    if abs(importe) > MAX_TICKET_IMPORTE:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El importe supera el maximo permitido",
        )

    try:
        return importe.quantize(Decimal("0.01"))
    except InvalidOperation:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El importe no es valido",
        )
