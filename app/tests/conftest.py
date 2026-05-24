import asyncio
import random
import string
import sys
from datetime import timedelta
from pathlib import Path

import httpx
import pytest

from app.main import app
from app.middlewares.jwt_auth import create_access_token

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


@pytest.fixture
def anyio_backend():
    return "asyncio"


class ASGITestClient:
    def __init__(self, app):
        self.app = app

    def post(self, url: str, **kwargs):
        return self._request("POST", url, **kwargs)

    def get(self, url: str, **kwargs):
        return self._request("GET", url, **kwargs)

    def _request(self, method: str, url: str, **kwargs):
        async def _send():
            transport = httpx.ASGITransport(app=self.app)
            async with httpx.AsyncClient(
                transport=transport,
                base_url="http://testserver",
            ) as client:
                return await client.request(method, url, **kwargs)

        return asyncio.run(_send())


@pytest.fixture(scope="session")
def client():
    return ASGITestClient(app)


@pytest.fixture(scope="session")
def headers():
    token = create_access_token(
        {"sub": "pytest"},
        expires_delta=timedelta(minutes=30),
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def generar_codigo_reserva():
    def _generate(length=15):
        return "".join(random.choices(string.ascii_letters + string.digits, k=length))

    return _generate


@pytest.fixture
def generar_matricula():
    def _generate():
        vocales = "AEIOU"
        consonantes = "BCDFGHJKLMNPQRSTVWXYZ"
        numeros = "0123456789"
        return "1234" + random.choice(vocales) + random.choice(consonantes) + random.choice(numeros)

    return _generate
