from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel, Session, select

from app.utils.dates import ahora


class SomosConfiguracion(SQLModel, table=True):
    __tablename__ = "hxxi_configuracion"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_app: int = Field(foreign_key="hxxi_aplicaciones.id")
    grupo: str = Field(max_length=45)
    nombre: str = Field(max_length=255)
    orden: int = 0
    label: Optional[str] = Field(default=None, max_length=100)
    valor: Optional[str] = Field(default=None, max_length=4000)
    tooltip: Optional[str] = Field(default=None, max_length=255)
    created_at: Optional[datetime] = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    modified_by: Optional[str] = Field(default=None, max_length=45)

    model_config = {
        "json_schema_extra": {
            "unique_constraints": [("id_app", "grupo", "nombre")]
        }
    }

    @staticmethod
    def get_config(
        session: Session,
        id_app: int,
        grupo: str,
        nombre: str,
    ) -> Optional["SomosConfiguracion"]:
        stmt = (
            select(SomosConfiguracion)
            .where(
                SomosConfiguracion.id_app == id_app,
                SomosConfiguracion.grupo == grupo,
                SomosConfiguracion.nombre == nombre,
            )
            .limit(1)
        )

        return session.exec(stmt).first()

    @staticmethod
    def get_value(
        session: Session,
        id_app: int,
        grupo: str,
        nombre: str,
        default: str = "",
    ) -> Optional[str]:
        config = SomosConfiguracion.get_config(session, id_app, grupo, nombre)
        return config.valor if config else default

    @staticmethod
    def set_value(
        session: Session,
        id_app: int,
        grupo: str,
        nombre: str,
        valor: str,
        modified_by: Optional[str] = None,
    ) -> "SomosConfiguracion":
        config = SomosConfiguracion.get_config(session, id_app, grupo, nombre)

        if config:
            config.valor = valor
            config.updated_at = ahora()
            if modified_by:
                config.modified_by = modified_by
        else:
            config = SomosConfiguracion(
                id_app=id_app,
                grupo=grupo,
                nombre=nombre,
                valor=valor,
                created_at=ahora(),
                updated_at=ahora(),
                modified_by=modified_by,
            )
            session.add(config)

        session.commit()
        session.refresh(config)
        return config
