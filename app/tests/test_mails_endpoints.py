import pytest
from unittest.mock import Mock, MagicMock, patch, AsyncMock
from fastapi import status
from io import BytesIO
from app.main import app
from app.config.db import get_db


def get_mock_db_success():
    mock_db = MagicMock()

    mock_app_servidor_result = MagicMock()
    mock_app_servidor_result.scalar_one_or_none.return_value = 1

    mock_servidor = MagicMock()
    mock_servidor.id = 1
    mock_servidor.de = "noreply@example.com"
    mock_servidor.de_nombre = "Sistema"
    mock_servidor.reply_to = "reply@example.com"

    mock_servidor_result = MagicMock()
    mock_servidor_result.scalar_one_or_none.return_value = mock_servidor

    mock_db.execute.side_effect = [
        mock_app_servidor_result,
        mock_servidor_result,
    ]

    return mock_db


def get_mock_db_no_servidor():
    mock_db = MagicMock()
    mock_app_servidor_result = MagicMock()
    mock_app_servidor_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_app_servidor_result
    return mock_db


def get_mock_db_mail_servidor_not_found():
    mock_db = MagicMock()

    mock_app_servidor_result = MagicMock()
    mock_app_servidor_result.scalar_one_or_none.return_value = 1

    mock_servidor_result = MagicMock()
    mock_servidor_result.scalar_one_or_none.return_value = None

    mock_db.execute.side_effect = [
        mock_app_servidor_result,
        mock_servidor_result,
    ]

    return mock_db


@patch("app.routers.mails.MailsService")
def test_send_mail_success(mock_mails_service_class, client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12345)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test de correo",
        "cuerpo": "<h1>Hola</h1><p>Este es un correo de prueba</p>",
        "send_now": "false",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ok"
    assert data["envio_id"] == 12345


@patch("app.routers.mails.MailsService")
def test_send_mail_with_all_fields(mock_mails_service_class, client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12346)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "id_participante": "100",
        "para": "destinatario@example.com",
        "para_nombre": "Usuario Destino",
        "de": "remitente@example.com",
        "de_nombre": "Remitente Test",
        "asunto": "Asunto completo",
        "cuerpo": "<p>Cuerpo del correo</p>",
        "cc": "copia@example.com",
        "bcc": "copiaoculta@example.com",
        "prioridad": "1",
        "reply_to": "responder@example.com",
        "clave_externa": "CLAVE123",
        "lenguaje": "es",
        "parametros": '{"nombre": "Juan"}',
        "fecha_envio": "2026-02-10 10:00:00",
        "identificador_externo": "EXT_001",
        "id_servidor": "1",
        "send_now": "true",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ok"
    assert data["envio_id"] == 12346


def test_send_mail_servidor_not_found_explicit(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_no_servidor

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
        "id_servidor": "999",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Servidor no encontrado" in response.json()["detail"]


def test_send_mail_no_servidor_available(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_no_servidor

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Servidor no encontrado" in response.json()["detail"]


@patch("app.routers.mails.shutil.copyfileobj")
@patch("app.routers.mails.MailsService")
def test_send_mail_with_attachments(
    mock_mails_service_class, mock_copyfileobj, client, headers
):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12347)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Correo con adjuntos",
        "cuerpo": "<p>Ver adjuntos</p>",
    }

    file_content = b"Contenido del archivo de prueba"
    files = [
        ("files", ("documento.pdf", BytesIO(file_content), "application/pdf")),
        ("files", ("imagen.png", BytesIO(file_content), "image/png")),
    ]

    with patch.dict("os.environ", {"APP_ID": "1", "MAIL_MEDIA_PATH": "/tmp/mail_test"}):
        with patch("builtins.open", MagicMock()):
            with patch("os.makedirs"):
                response = client.post(
                    "/bo/mail/send",
                    data=form_data,
                    files=files,
                    headers=headers,
                )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ok"


def test_send_mail_mail_servidor_not_found(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_mail_servidor_not_found

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Servidor no encontrado" in response.json()["detail"]


def test_send_mail_missing_required_fields(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    form_data = {
        "user": "admin",
    }

    response = client.post(
        "/bo/mail/send",
        data=form_data,
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_send_mail_missing_user(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    form_data = {
        "para": "destinatario@example.com",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
    }

    response = client.post(
        "/bo/mail/send",
        data=form_data,
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_send_mail_missing_para(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    form_data = {
        "user": "admin",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
    }

    response = client.post(
        "/bo/mail/send",
        data=form_data,
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_send_mail_missing_asunto(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "cuerpo": "Cuerpo",
    }

    response = client.post(
        "/bo/mail/send",
        data=form_data,
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_send_mail_missing_cuerpo(client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test",
    }

    response = client.post(
        "/bo/mail/send",
        data=form_data,
        headers=headers,
    )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.parametrize("lenguaje", ["es", "en", "fr", "de", "it", "pt"])
@patch("app.routers.mails.MailsService")
def test_send_mail_different_languages(
    mock_mails_service_class, client, headers, lenguaje
):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12348)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
        "lenguaje": lenguaje,
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK


@pytest.mark.parametrize("prioridad", [1, 2, 3, 4, 5])
@patch("app.routers.mails.MailsService")
def test_send_mail_different_priorities(
    mock_mails_service_class, client, headers, prioridad
):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12349)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Test",
        "cuerpo": "Cuerpo",
        "prioridad": str(prioridad),
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK


@patch("app.routers.mails.MailsService")
def test_send_mail_send_now_true(mock_mails_service_class, client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12350)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Envío inmediato",
        "cuerpo": "Este correo se envía ahora",
        "send_now": "true",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    mock_service.send_mail.assert_called_once()
    call_kwargs = mock_service.send_mail.call_args[1]
    assert call_kwargs["send_now"] == True


@patch("app.routers.mails.MailsService")
def test_send_mail_scheduled(mock_mails_service_class, client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12351)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Envío programado",
        "cuerpo": "Este correo se envía más tarde",
        "fecha_envio": "2026-02-15 09:00:00",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    mock_service.send_mail.assert_called_once()
    call_kwargs = mock_service.send_mail.call_args[1]
    assert call_kwargs["fecha_envio"] == "2026-02-15 09:00:00"


@patch("app.routers.mails.MailsService")
def test_send_mail_with_cc_and_bcc(mock_mails_service_class, client, headers):
    app.dependency_overrides[get_db] = get_mock_db_success

    mock_service = MagicMock()
    mock_service.send_mail = AsyncMock(return_value=12352)
    mock_mails_service_class.return_value = mock_service

    form_data = {
        "user": "admin",
        "para": "destinatario@example.com",
        "asunto": "Correo con copias",
        "cuerpo": "Contenido",
        "cc": "copia1@example.com,copia2@example.com",
        "bcc": "oculto@example.com",
    }

    with patch.dict("os.environ", {"APP_ID": "1"}):
        response = client.post(
            "/bo/mail/send",
            data=form_data,
            headers=headers,
        )

    app.dependency_overrides.clear()

    assert response.status_code == status.HTTP_200_OK
    mock_service.send_mail.assert_called_once()
    call_kwargs = mock_service.send_mail.call_args[1]
    assert call_kwargs["cc"] == "copia1@example.com,copia2@example.com"
    assert call_kwargs["bcc"] == "oculto@example.com"
