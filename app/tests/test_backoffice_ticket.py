from datetime import datetime, timezone
from decimal import Decimal
from io import BytesIO
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException, status

from app.config.db import get_db
from app.main import app
from app.schemas.tickets import TicketValidaResponse
from app.services.tickets import TicketsService


def get_mock_db():
    return MagicMock()


@patch("app.routers.backoffice.TicketsService")
def test_validar_ticket_endpoint_success(mock_service_class, client, headers):
    app.dependency_overrides[get_db] = get_mock_db

    mock_service = MagicMock()
    mock_service.validar_ticket = AsyncMock(
        return_value=TicketValidaResponse(
            texto="Ticket validado correctamente",
            cupon="ABCD",
            id_cupon=12345,
        )
    )
    mock_service_class.return_value = mock_service

    response = client.post(
        "/bo/ticket/valida",
        data={
            "id_app": "1",
            "user": "admin",
            "id_campana": "10",
            "numero_ticket": "TCK-001",
            "fecha": "2026-05-24T14:30:00+02:00",
            "importe": "12.30",
        },
        files={"imagen": ("ticket.jpg", BytesIO(b"image"), "image/jpeg")},
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    assert response.json() == {
        "texto": "Ticket validado correctamente",
        "cupon": "ABCD",
        "id_cupon": 12345,
    }

    call_kwargs = mock_service.validar_ticket.call_args.kwargs
    assert call_kwargs["id_app"] == 1
    assert call_kwargs["user"] == "admin"
    assert call_kwargs["id_campana"] == 10
    assert call_kwargs["numero_ticket"] == "TCK-001"
    assert call_kwargs["importe"] == Decimal("12.30")


@patch("app.routers.backoffice.TicketsService")
def test_validar_ticket_endpoint_rejects_importe_more_than_two_decimals(
    mock_service_class, client, headers
):
    app.dependency_overrides[get_db] = get_mock_db

    response = client.post(
        "/bo/ticket/valida",
        data={
            "id_app": "1",
            "user": "admin",
            "id_campana": "10",
            "numero_ticket": "TCK-001",
            "fecha": "2026-05-24T14:30:00+02:00",
            "importe": "12.345",
        },
        files={"imagen": ("ticket.jpg", BytesIO(b"image"), "image/jpeg")},
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    mock_service_class.return_value.validar_ticket.assert_not_called()


@pytest.mark.anyio
@patch("app.services.tickets.call_db_procedure_no_exception", new_callable=AsyncMock)
async def test_tickets_service_sends_madrid_datetime(mock_call_proc):
    mock_call_proc.return_value = {
        "v_retNum": 0,
        "v_retTxt": "OK",
        "v_cupon": "ABCD",
        "v_id": 12345,
    }

    service = TicketsService()
    service._save_ticket_image = AsyncMock(
        return_value={"url": "app/media/tickets/ticket.jpg"}
    )

    response = await service.validar_ticket(
        db=MagicMock(),
        id_app=1,
        user="admin",
        imagen=MagicMock(),
        id_campana=10,
        numero_ticket="TCK-001",
        fecha_ticket=datetime(2026, 5, 24, 12, 30, tzinfo=timezone.utc),
        importe=Decimal("12.30"),
    )

    assert response.texto == "OK"
    assert response.cupon == "ABCD"
    assert response.id_cupon == 12345

    ordered_params = dict(mock_call_proc.call_args.kwargs["ordered_params"])
    assert ordered_params["v_fecha"] == "2026-05-24 14:30:00"
    assert ordered_params["v_ticket"] == "app/media/tickets/ticket.jpg"
    assert ordered_params["v_numero_ticket"] == "TCK-001"
    assert ordered_params["v_importe"] == 12.3


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("ret_num", "expected_status"),
    [
        (-99, status.HTTP_406_NOT_ACCEPTABLE),
        (-1, status.HTTP_410_GONE),
    ],
)
@patch("app.services.tickets.call_db_procedure_no_exception", new_callable=AsyncMock)
async def test_tickets_service_maps_negative_ret_nums(
    mock_call_proc, ret_num, expected_status
):
    mock_call_proc.return_value = {
        "v_retNum": ret_num,
        "v_retTxt": "Error controlado",
    }

    service = TicketsService()
    service._save_ticket_image = AsyncMock(
        return_value={"url": "app/media/tickets/ticket.jpg"}
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.validar_ticket(
            db=MagicMock(),
            id_app=1,
            user="admin",
            imagen=MagicMock(),
            id_campana=10,
            numero_ticket="TCK-001",
            fecha_ticket=datetime(2026, 5, 24, 14, 30),
            importe=Decimal("12.30"),
        )

    assert exc_info.value.status_code == expected_status
    assert exc_info.value.detail == "Error controlado"
