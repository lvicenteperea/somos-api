import os
import time
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

pytestmark = pytest.mark.integration

if os.getenv("RUN_INTEGRATION_TESTS") != "1":
    pytest.skip("requiere BBDD y proveedor SendGrid real", allow_module_level=True)

from app.main import app
from app.config.db import get_db_manager
from app.models.mail.mail_envios import MailEnvio

client = TestClient(app)

TEST_ID_SERVIDOR = 3
MEDIA_DIR = Path(os.getenv("MAIL_MEDIA_PATH", "app/media/mail"))


@pytest.fixture(scope="function")
def db_session():
    manager = get_db_manager()
    with manager.get_session() as session:
        yield session


def _find_saved_files(original_names):
    """
    Busca en app/media/mail ficheros cuyo nombre termine con alguno de los originales.
    Devuelve un dict {original_name: [paths_encontrados]}.
    """
    found = {name: [] for name in original_names}
    if MEDIA_DIR.exists():
        for p in MEDIA_DIR.iterdir():
            if p.is_file():
                for name in original_names:
                    if str(p.name).endswith(name):
                        found[name].append(str(p))
    return found


def test_send_mail_delayed(db_session: Session):
    """
    Test enviar email con send_now=False (queda en estado P)
    """
    response = client.post("/bo/mail/send", data={
        "id_app": 1,
        "user": "tester",
        "id_servidor": TEST_ID_SERVIDOR,
        "para": "davidpedro.chico@gmail.com",
        "asunto": "Test retrasado",
        "cuerpo": "Este es un mail en espera",
        "send_now": False
    })
    assert response.status_code == 200
    envio_id = response.json()["envio_id"]

    stmt = select(MailEnvio).where(MailEnvio.id == envio_id)
    result = db_session.exec(stmt).first()
    assert result is not None
    assert result.estado == "P"


def test_send_mail_immediate(db_session: Session):
    """
    Test enviar email con send_now=True
    """
    response = client.post("/bo/mail/send", data={
        "id_app": 1,
        "user": "tester",
        "id_servidor": TEST_ID_SERVIDOR,
        "para": "davidpedro.chico@gmail.com",
        "asunto": "Test inmediato",
        "cuerpo": "Este es un mail enviado al instante",
        "send_now": True
    })
    assert response.status_code == 200
    envio_id = response.json()["envio_id"]

    time.sleep(1)  # breve espera para que se procese

    stmt = select(MailEnvio).where(MailEnvio.id == envio_id)
    result = db_session.exec(stmt).first()
    assert result is not None
    assert result.estado in ("O", "E")  # OK o Error


def test_send_mail_delayed_with_attachments(db_session: Session):
    """
    Envío diferido con adjuntos: debe quedar en estado P y los adjuntos persistidos en disco.
    """
    files = [
        ("files", ("nota.txt", b"hola mundo", "text/plain")),
        ("files", ("doc.pdf", b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n", "application/pdf")),
    ]
    data = {
        "id_app": 1,
        "user": "tester",
        "id_servidor": TEST_ID_SERVIDOR,
        "para": "davidpedro.chico@gmail.com",
        "asunto": "Test retrasado con adjuntos",
        "cuerpo": "Adjunto: {{nombre_doc}}",
        "parametros": json.dumps({"nombre_doc": "doc.pdf"}),
        "send_now": False,
    }
    resp = client.post("/bo/mail/send", data=data, files=files)
    assert resp.status_code == 200
    envio_id = resp.json()["envio_id"]

    # Estado P
    stmt = select(MailEnvio).where(MailEnvio.id == envio_id)
    envio = db_session.exec(stmt).first()
    assert envio is not None
    assert envio.estado == "P"

    # Los ficheros deben existir en app/media/mail con sufijo original
    found = _find_saved_files(["nota.txt", "doc.pdf"])
    assert any(found["nota.txt"]), "No se encontró nota.txt en app/media/mail"
    assert any(found["doc.pdf"]), "No se encontró doc.pdf en app/media/mail"


def test_send_mail_immediate_with_attachments(db_session: Session):
    """
    Envío inmediato con adjuntos: el estado debe pasar a O o E.
    Además, los ficheros deben persistir en app/media/mail.
    """
    files = [
        ("files", ("reporte.csv", b"a,b,c\n1,2,3\n", "text/csv")),
        ("files", ("imagen.png", b"\x89PNG\r\n\x1a\n", "image/png")),
    ]
    # cuerpo con HTML para probar detección heurística
    body = "<html><body><p>Hola {{nombre}}</p></body></html>"
    data = {
        "id_app": 1,
        "user": "tester",
        "id_servidor": TEST_ID_SERVIDOR,
        "para": "davidpedro.chico@gmail.com",
        "asunto": "Test inmediato con adjuntos",
        "cuerpo": body,
        "parametros": json.dumps({"nombre": "Tester"}),
        "send_now": True,
    }
    resp = client.post("/bo/mail/send", data=data, files=files)
    assert resp.status_code == 200
    envio_id = resp.json()["envio_id"]

    time.sleep(1.5)

    stmt = select(MailEnvio).where(MailEnvio.id == envio_id)
    envio = db_session.exec(stmt).first()
    assert envio is not None
    assert envio.estado in ("O", "E")

    # Los ficheros deben existir en app/media/mail con sufijo original
    found = _find_saved_files(["reporte.csv", "imagen.png"])
    assert any(found["reporte.csv"]), "No se encontró reporte.csv en app/media/mail"
    assert any(found["imagen.png"]), "No se encontró imagen.png en app/media/mail"


def test_bo_send_mail_immediate_with_qr_inline(db_session: Session):
    """
    Envío inmediato vía /bo/mail/send con parámetro qr_html_image:
    - Debe procesarse el envío (estado O o E)
    - Debe generarse un PNG de QR en app/media/mail con sufijo qrcode.png.
    """
    qr_payload = "bo-qr-test-payload-456"
    body = "<html><body><p>BO Hola</p><p>Aquí tu QR: {{qr_html_image}}</p></body></html>"

    data = {
        "id_app": 1,
        "user": "tester",
        "id_servidor": TEST_ID_SERVIDOR,
        "para": "davidpedro.chico@gmail.com",
        "asunto": "BO Test inmediato con QR",
        "cuerpo": body,
        "parametros": json.dumps({"qr_html_image": qr_payload}),
        "send_now": True,
    }

    resp = client.post("/bo/mail/send", data=data)
    assert resp.status_code == 200
    envio_id = resp.json()["envio_id"]

    time.sleep(1.5)

    stmt = select(MailEnvio).where(MailEnvio.id == envio_id)
    envio = db_session.exec(stmt).first()
    assert envio is not None
    assert envio.estado in ("O", "E")

    found = _find_saved_files(["qrcode.png"])
    assert any(found["qrcode.png"]), "No se encontró el PNG del QR en app/media/mail (BO)"
