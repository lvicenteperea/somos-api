from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field, Relationship

from sqlalchemy.orm import Session
from sqlmodel import select
from app.utils.dates import ahora



class SomosConfiguracion(SQLModel, table=True):
    __tablename__ = "somos_configuracion"

    id: Optional[int] = Field(default=None, primary_key=True)
    id_app: int = Field(foreign_key="somos_aplicaciones.id", description="ID de la aplicación")
    grupo: str = Field(max_length=45, description="Grupo de configuración")
    nombre: str = Field(max_length=255, description="Nombre de la configuración")
    orden: int = Field(default=0, description="Orden de presentación")
    label: Optional[str] = Field(default=None, max_length=100, description="Etiqueta visible en la interfaz")
    valor: Optional[str] = Field(default=None, max_length=4000, description="Valor de la configuración")
    tooltip: Optional[str] = Field(default=None, max_length=255, description="Texto de ayuda (tooltip)")
    created_at: Optional[datetime] = Field(default_factory=datetime.utcnow, description="Fecha de creación")
    updated_at: Optional[datetime] = Field(default=None, description="Fecha de última actualización")
    modified_by: Optional[str] = Field(default=None, max_length=45, description="Usuario que modificó por última vez")

    # Relaciones (si deseas acceder al objeto somos_aplicaciones)
    # aplicacion: Optional["SomosAplicacion"] = Relationship(back_populates="configuraciones")

    class Config:
        json_schema_extra = {
            "unique_constraints": [("id_app", "grupo", "nombre")]
        }

    @staticmethod
    def get_config(
            session: Session,
            id_app: int,
            grupo: str,
            nombre: str
    ) -> Optional["SomosConfiguracion"]:
        stmt = select(SomosConfiguracion).where(
            SomosConfiguracion.id_app == id_app,
            SomosConfiguracion.grupo == grupo,
            SomosConfiguracion.nombre == nombre
        ).limit(1)

        result = session.exec(stmt).first()
        # print("resultado: ",id_app, grupo, nombre, result)
        return result

    @staticmethod
    def get_value(
            session: Session,
            id_app: int,
            grupo: str,
            nombre: str,
            default=""
    ) -> Optional[str]:
        config = SomosConfiguracion.get_config(session, id_app, grupo, nombre)

        if config:
            return config.valor
        return default

    @staticmethod
    def set_value(
            session: Session,
            id_app: int,
            grupo: str,
            nombre: str,
            valor: str,
            modified_by: Optional[str] = None
    ) -> "SomosConfiguracion":
        config = SomosConfiguracion.get_config(session, id_app, grupo, nombre)

        if config:
            config.valor = valor
            config.updated_at = ahora()  # Cambio fecha aqui
            if modified_by:
                config.modified_by = modified_by
        else:
            config = SomosConfiguracion(
                id_app=id_app,
                grupo=grupo,
                nombre=nombre,
                valor=valor,
                created_at=ahora(),  # Cambio fecha aqui
                updated_at=ahora(),  # Cambio fecha aqui
                modified_by=modified_by
            )
            session.add(config)

        session.commit()
        session.refresh(config)
        return config
