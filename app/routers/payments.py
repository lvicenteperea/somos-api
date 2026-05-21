from fastapi import (
    APIRouter,
    Request,
    HTTPException,
    Depends,
    Body,
    Query,
    BackgroundTasks,
)
from fastapi.responses import JSONResponse, RedirectResponse
from sqlalchemy import select

from app.config.db import get_db_manager
from app.payments.payment_handler import PaymentHandler
from app.models.payment.api_card import ApiCard
from app.models.payment.api_payment import ApiPayment
from app.models.payment.api_payment_credentials import ApiPaymentCredential
from app.schemas.payments import (
    OneTimePaymentUrlRequest,
    CardTokenizationUrlRequest,
    OneTimePaymentCardRequest,
    OneTimePaymentUrlResponse,
    CardTokenizationUrlResponse,
    CardInfoResponse,
    StatusResponse,
    CardPaymentResponse,
    WebhookResponse,
)

from sqlalchemy import text
from app.config.db import get_db_manager
from app.utils.auth import allow_anonymous

router = APIRouter(prefix="/bo/payment", tags=["payment"])


@router.post(
    "/one_time/url",
    response_model=OneTimePaymentUrlResponse,
    summary="Obtener URL de pago único",
    description="Genera una URL de redirección para que el usuario complete un pago único a través de la pasarela de pagos. Devuelve la URL y el ID del pago creado.",
)
async def one_time_payment_url(
    request: Request, data: OneTimePaymentUrlRequest
) -> OneTimePaymentUrlResponse:
    try:
        handler = PaymentHandler(data.id_tpv)
        redirect_url, payment_id = await handler.get_one_time_payment_url(
            request,
            data.amount,
            data.currency,
            data.url_ok,
            data.url_ko,
            data.description,
            data.modulo_ref,
            data.language,
        )
        return JSONResponse({"redirect_url": redirect_url, "id": payment_id})
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/redirect/one_time/success/{order}",
    summary="Redirección de pago exitoso",
    description="Endpoint de callback tras un pago exitoso. Redirige al usuario a la URL de éxito (ok_url) configurada en el pago. Este endpoint es llamado automáticamente por la pasarela de pagos.",
    responses={307: {"description": "Redirección a la URL de éxito del pago"}},
)
@allow_anonymous
async def redirect_one_time_ok(request: Request, order: str):
    db_manager = get_db_manager()
    print("WEBHOOK redirect_one_time_ok")
    with db_manager.get_session() as session:
        stmt = select(ApiPayment).where(ApiPayment.ref_ext == order)
        result = session.execute(stmt)
        payment = result.scalars().first()

        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        # Obtener el id_tpv desde ApiPayment.credentials_id
        creds = session.get(ApiPaymentCredential, payment.credentials_id)
        if not creds:
            raise HTTPException(
                status_code=404, detail=f"TPV no encontrado: {payment.credentials_id}"
            )

        handler = PaymentHandler(creds.id_tpv)
        return RedirectResponse(
            await handler.handle_one_time_payment_ok(request, order)
        )


@router.get(
    "/redirect/one_time/fail/{order}",
    summary="Redirección de pago fallido",
    description="Endpoint de callback tras un pago fallido. Redirige al usuario a la URL de error (ko_url) configurada en el pago. Este endpoint es llamado automáticamente por la pasarela de pagos.",
    responses={307: {"description": "Redirección a la URL de error del pago"}},
)
@allow_anonymous
async def redirect_one_time_ko(request: Request, order: str):
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        stmt = select(ApiPayment).where(ApiPayment.ref_ext == order)
        result = session.execute(stmt)
        payment = result.scalars().first()

        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        creds = session.get(ApiPaymentCredential, payment.credentials_id)
        if not creds:
            raise HTTPException(
                status_code=404, detail=f"TPV no encontrado (fail): {payment.credentials_id}"
            )

        handler = PaymentHandler(creds.id_tpv)
        return RedirectResponse(
            await handler.handle_one_time_payment_ko(request, order)
        )


@router.post(
    "/card/url",
    response_model=CardTokenizationUrlResponse,
    summary="Obtener URL de tokenización de tarjeta",
    description="Genera una URL de redirección para que el usuario registre una tarjeta de forma segura. Devuelve la URL y el ID de la tarjeta creada.",
)
async def create_card_tokenization_url(
    request: Request, data: CardTokenizationUrlRequest
) -> CardTokenizationUrlResponse:
    try:
        handler = PaymentHandler(data.id_tpv)
        redirect_url, card_id = await handler.get_card_url(
            request, data.url_ok, data.url_ko, data.language, data.amount
        )
        return JSONResponse({"redirect_url": redirect_url, "id": card_id})
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/redirect/card/success/{order}",
    summary="Redirección de tokenización exitosa",
    description="Endpoint de callback tras una tokenización de tarjeta exitosa. Redirige al usuario a la URL de éxito (ok_url) configurada. Este endpoint es llamado automáticamente por la pasarela de pagos.",
    responses={307: {"description": "Redirección a la URL de éxito de la tarjeta"}},
)
@allow_anonymous
async def redirect_card_ok(request: Request, order: str):
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        stmt = select(ApiPayment).where(ApiPayment.ref_ext == order)
        result = session.execute(stmt)
        payment = result.scalars().first()

        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        creds = session.get(ApiPaymentCredential, payment.credentials_id)
        if not creds:
            raise HTTPException(
                status_code=404, detail=f"TPV no encontrado :{payment.credentials_id}"
            )

        handler = PaymentHandler(creds.id_tpv)
        return RedirectResponse(await handler.handle_card_ok(request, order))


@router.get(
    "/redirect/card/fail/{order}",
    summary="Redirección de tokenización fallida",
    description="Endpoint de callback tras una tokenización de tarjeta fallida. Redirige al usuario a la URL de error (ko_url) configurada. Este endpoint es llamado automáticamente por la pasarela de pagos.",
    responses={307: {"description": "Redirección a la URL de error de la tarjeta"}},
)
@allow_anonymous
async def redirect_card_ko(request: Request, order: str):
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        stmt = select(ApiPayment).where(ApiPayment.ref_ext == order)
        result = session.execute(stmt)
        payment = result.scalars().first()

        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")

        creds = session.get(ApiPaymentCredential, payment.credentials_id)
        if not creds:
            raise HTTPException(
                status_code=404, detail=f"TPV no encontrado : {payment.credentials_id}"
            )

        handler = PaymentHandler(creds.id_tpv)
        return RedirectResponse(await handler.handle_card_ko(request, order))


# app/api/bo/payment.py (mismo router)
@router.get(
    "/card/{card_id}/info",
    response_model=CardInfoResponse,
    summary="Obtener información de una tarjeta",
    description="Obtiene la información pública de una tarjeta tokenizada: estado, número enmascarado, fechas de caducidad y creación.",
)
async def get_card_public_info(card_id: int) -> CardInfoResponse:
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        card = session.get(ApiCard, card_id)
        if not card:
            raise HTTPException(status_code=404, detail="Card not found")

        return {
            "id": card.id,
            "status": (
                card.status.value if hasattr(card.status, "value") else str(card.status)
            ),
            "masked_pan": card.masked_pan,
            "card_expire_date": (
                card.card_expire_date.isoformat() if card.card_expire_date else None
            ),
            "created_at": card.date.isoformat(),
            "recurring_expiry_date": (
                card.recurring_expiry_date.isoformat()
                if card.recurring_expiry_date
                else None
            ),
        }


@router.delete(
    "/card/{card_id}",
    response_model=StatusResponse,
    summary="Eliminar una tarjeta",
    description="Elimina una tarjeta tokenizada del sistema. La eliminación se procesa en segundo plano en la pasarela de pagos.",
)
async def delete_card(
    background_tasks: BackgroundTasks, card_id: int
) -> StatusResponse:
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        card = session.get(ApiCard, card_id)
        if not card:
            raise HTTPException(status_code=404, detail="Card not found")

        creds = session.get(ApiPaymentCredential, card.credentials_id)
        if not creds:
            raise HTTPException(
                status_code=404, detail=f"TPV no encontrado --> {card.credentials_id}"
            )

        handler = PaymentHandler(creds.id_tpv)
        background_tasks.add_task(handler.delete_card, card_id)
        return JSONResponse({"status": "ok"})


# TODO Check Card Endpoint


@router.post(
    "/one_time/card",
    response_model=CardPaymentResponse,
    summary="Pago único con tarjeta tokenizada",
    description="Procesa un pago único utilizando una tarjeta previamente tokenizada. No requiere interacción del usuario. El estado final del pago se confirma mediante webhook.",
)
async def one_time_payment_card(
    request: Request, data: OneTimePaymentCardRequest
) -> CardPaymentResponse:
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        card = session.get(ApiCard, data.card_id)
        if not card:
            raise HTTPException(status_code=404, detail="Card not found")

        creds = session.get(ApiPaymentCredential, card.credentials_id)
        if not creds:
            raise HTTPException(
                status_code=404, detail=f"TPV no encontrado-->{card.credentials_id}"
            )

        handler = PaymentHandler(creds.id_tpv)
        result = await handler.process_card_payment(
            request=request,
            card_id=data.card_id,
            amount_eur=data.amount,
            currency=data.currency,
            modulo_ref=data.modulo_ref,
            language=data.language,
        )
        return result


@router.post(
    "/webhook/paycomet/{id_tpv}",
    response_model=WebhookResponse,
    summary="Webhook de Paycomet",
    description="Endpoint para recibir notificaciones de la pasarela Paycomet. Procesa eventos de pagos y tokenizaciones. Este endpoint es llamado automáticamente por Paycomet.",
)
@allow_anonymous
async def paycomet_webhook(request: Request, id_tpv: int) -> WebhookResponse:
    # Opcional: si vas a usar un TPV específico, pásalo como parámetro
    # O recupera el primer TPV Paycomet que tengas
    handler = PaymentHandler(id_tpv)
    return await handler.handle_operation_webhook(request)
