from pydantic import BaseModel, Field


class SendMailResponse(BaseModel):
    """Respuesta del envío de correo electrónico."""

    status: str = Field(
        ...,
        description="Estado del envío",
        json_schema_extra={"example": "ok"},
    )
    envio_id: int = Field(
        ...,
        description="ID del envío creado",
        json_schema_extra={"example": 12345},
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "status": "ok",
                "envio_id": 12345,
            }
        }
    }
