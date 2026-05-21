import os
import time
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.main import app
from app.config.db import get_db_manager
from app.models.mail.mail_envios import MailEnvio

from app.services.mails import MailsService

client = TestClient(app)
MEDIA_DIR = Path(os.getenv("MAIL_MEDIA_PATH", "app/media/mail"))


@pytest.fixture(scope="function")
def db_session():
    manager = get_db_manager()
    with manager.get_session() as session:
        yield session



@pytest.mark.asyncio
async def test_send_mail_immediate(db_session: Session):
    """
    Test enviar email
    """
    data = {"tipo": "error", "modulo": "reservas", "detalle": {"code": 123, "msg": "Fallo de prueba"}}

    id_mail = await MailsService.send_notification_email(
        db_session,
        "Test mail error",
        "Test mail error",
        data
    )

    assert id_mail > 0


