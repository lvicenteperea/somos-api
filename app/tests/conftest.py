import pytest
from fastapi.testclient import TestClient
from app.main import app
import random
import string
import sys
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)
    
# --- Registrar nuevas opciones de ini ---
def pytest_addoption(parser):
    parser.addini("auth_username", "Usuario para /bo/auth", default="")
    parser.addini("auth_password", "Password para /bo/auth", default="")


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture(scope="session")
def client():
    return TestClient(app)


@pytest.fixture(scope="session")
def headers(client, pytestconfig):
    """Hace login en /bo/auth y devuelve headers con Bearer token"""

    username = pytestconfig.getini("auth_username")
    password = pytestconfig.getini("auth_password")

    if not username or not password:
        raise RuntimeError("⚠️ Configura auth_username y auth_password en pytest.local.ini")

    resp_auth = client.post("/bo/auth", json={"username": username, "password": password})
    assert resp_auth.status_code == 200, f"Fallo en auth: {resp_auth.status_code} - {resp_auth.text}"

    data = resp_auth.json()
    token = data.get("access_token") or data.get("bearer")
    assert token, f"No se recibió token en respuesta de /bo/auth: {resp_auth.text}"


    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def generar_codigo_reserva():
    def _generate(length=15):
        return ''.join(random.choices(string.ascii_letters + string.digits, k=length))
    return _generate


@pytest.fixture
def generar_matricula():
    def _generate():
        vocales = "AEIOU"
        consonantes = "BCDFGHJKLMNPQRSTVWXYZ"
        numeros = "0123456789"
        return "1234" + random.choice(vocales) + random.choice(consonantes) + random.choice(numeros)
    return _generate
