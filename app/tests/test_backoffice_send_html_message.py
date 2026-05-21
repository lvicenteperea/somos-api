import pytest
from unittest.mock import AsyncMock, patch, Mock
from fastapi.testclient import TestClient
from app.main import app  # Asumiendo que app está en main.py
from app.config.db import get_db
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_db():
    return AsyncMock(spec=AsyncSession)


@patch("app.config.db.get_db")
@patch("app.routers.backoffice.RaspberryService")
def test_send_html_message_custom_success(
    mock_raspberry_service, mock_get_db, client, mock_db
):
    mock_get_db.return_value = mock_db
    mock_service = AsyncMock()
    mock_service.send_html.return_value = None
    mock_raspberry_service.return_value = mock_service

    payload = {
        "terminal": "0001",
        "tipo_mensaje": "custom",
        "mensaje": "<h1>Mensaje personalizado</h1>",
        "duracion": 5000,
    }

    response = client.post("/bo/send-html-message", json=payload)

    assert response.status_code == 200

    data = response.json()
    assert data["message"] == "Mensaje enviado correctamente al terminal"
    assert data["terminal"] == "0001"

    mock_service.send_html.assert_called_once_with(
        "0001", "<h1>Mensaje personalizado</h1>", 5000
    )


@patch("app.config.db.get_db")
@patch("app.routers.backoffice.RaspberryService")
def test_send_html_message_default_success(
    mock_raspberry_service, mock_get_db, client, mock_db
):
    mock_get_db.return_value = mock_db
    mock_service = AsyncMock()
    mock_service.send_html.return_value = None
    mock_raspberry_service.return_value = mock_service

    payload = {"terminal": "0002", "tipo_mensaje": "default", "duracion": 3000}

    response = client.post("/bo/send-html-message", json=payload)

    assert response.status_code == 200

    data = response.json()
    assert data["message"] == "Mensaje enviado correctamente al terminal"
    assert data["terminal"] == "0002"

    mock_service.send_html.assert_called_once_with("0002", None, 3000)


@patch("app.config.db.get_db")
def test_send_html_message_invalid_tipo_mensaje(mock_get_db, client, mock_db):
    mock_get_db.return_value = mock_db

    payload = {
        "terminal": "0001",
        "tipo_mensaje": "invalid",
        "mensaje": "<h1>Test</h1>",
        "duracion": 5000,
    }

    response = client.post("/bo/send-html-message", json=payload)

    assert response.status_code == 400
    data = response.json()
    assert "Tipo de mensaje 'invalid' no válido" in data["detail"]


@patch("app.config.db.get_db")
@patch("app.routers.backoffice.RaspberryService")
def test_send_html_message_service_error(
    mock_raspberry_service, mock_get_db, client, mock_db
):
    mock_get_db.return_value = mock_db
    mock_service = AsyncMock()
    mock_service.send_html.side_effect = Exception("Error en el servicio")
    mock_raspberry_service.return_value = mock_service

    payload = {
        "terminal": "0001",
        "tipo_mensaje": "custom",
        "mensaje": "<h1>Test</h1>",
        "duracion": 5000,
    }

    response = client.post("/bo/send-html-message", json=payload)

    assert response.status_code == 500
    data = response.json()
    assert "Error al enviar mensaje HTML al terminal" in data["detail"]


@patch("app.config.db.get_db")
def test_send_html_message_custom_missing_mensaje(mock_get_db, client, mock_db):
    mock_get_db.return_value = mock_db

    payload = {
        "terminal": "0001",
        "duracion": 5000,
        "mensaje": "<h1>Test</h1>",
    }
    response = client.post("/bo/send-html-message", json=payload)
    assert response.status_code == 422
