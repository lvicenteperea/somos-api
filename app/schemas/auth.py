from pydantic import BaseModel
from typing import Optional


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    username: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str

    model_config = {
        "json_schema_extra": {
            "examples": [
                {"username": "usuario@ejemplo.com", "password": "contraseña123"}
            ]
        }
    }


class AuthResponse(BaseModel):
    """Respuesta del endpoint de autenticación."""

    bearer: str

    model_config = {
        "json_schema_extra": {
            "example": {
                "bearer": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3VhcmlvQGVqZW1wbG8uY29tIiwiZXhwIjoxNzA5MTIzNDU2fQ.abc123...",
            }
        }
    }
