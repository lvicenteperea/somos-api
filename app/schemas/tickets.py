from typing import Optional

from pydantic import BaseModel, Field


class TicketValidaResponse(BaseModel):
    """Respuesta de la validacion de ticket."""

    texto: str = Field(
        ...,
        description="Texto devuelto por el procedimiento",
        json_schema_extra={"example": "Ticket validado correctamente"},
    )
    cupon: Optional[str] = Field(
        None,
        description="Slug del cupon obtenido",
        json_schema_extra={"example": "ABCD"},
    )
    id_cupon: Optional[int] = Field(
        None,
        description="ID del cupon obtenido",
        json_schema_extra={"example": 12345},
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "texto": "Ticket validado correctamente",
                "cupon": "ABCD",
                "id_cupon": 12345,
            }
        }
    }
