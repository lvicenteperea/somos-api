import sys
import os
import typer
import json
from dotenv import load_dotenv
from cryptography.fernet import Fernet

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.models.mail.mail_servidores import MailServidor
from app.config.db import get_db_manager

from datetime import datetime
from app.models.mail.mail_app_servidores import MailAppServidor

load_dotenv()
app = typer.Typer()

SUPPORTED_PROVIDERS = {
    "smtp": ["host", "port", "username", "password", "use_tls", "use_ssl"],
    "sendgrid": ["api_key"]
}


def get_fernet() -> Fernet:
    key = os.getenv("API_PAYMENTS_KEY")
    if not key:
        raise ValueError("API_PAYMENTS_KEY no definido")
    return Fernet(key)


@app.command()
def create(sql: bool = typer.Option(False, help="Mostrar también el INSERT SQL generado")):
    """
    Crear servidor de email en la base de datos con credenciales cifradas.
    """

    id_app = typer.prompt("ID del app", type=int)
    nombre = typer.prompt("Nombre del servidor")
    nombre_clase = ""
    orden_servidor = typer.prompt("Orden de prioridad del servidor", type=int)
    de = typer.prompt("Dirección 'from' (de)")
    de_nombre = typer.prompt("Nombre del remitente (de_nombre)")
    reply_to = typer.prompt("Email de reply-to")
    # usuario = typer.prompt("Usuario")
    # password = typer.prompt("Password", hide_input=True)
    usuario = ""
    password = ""

    # Selección del proveedor
    typer.echo("Proveedores disponibles:")
    for i, provider in enumerate(SUPPORTED_PROVIDERS.keys()):
        typer.echo(f"{i + 1}. {provider}")

    choice = typer.prompt("Selecciona el número del proveedor")
    try:
        provider_key = list(SUPPORTED_PROVIDERS.keys())[int(choice) - 1]
        nombre_clase = provider_key
    except (IndexError, ValueError):
        typer.echo("Selección inválida.")
        raise typer.Exit(1)

    # Credenciales específicas
    fields = SUPPORTED_PROVIDERS[provider_key]
    cred_data = {}

    typer.echo(f"Introduce los datos para el proveedor '{provider_key}':")
    for field in fields:
        cred_data[field] = typer.prompt(f"{field}", hide_input=("password" in field.lower()))

    # Cifrar credenciales
    fernet = get_fernet()
    json_data = json.dumps(cred_data)
    encrypted = fernet.encrypt(json_data.encode("utf-8")).decode("utf-8")

    servidor = MailServidor(
        nombre=nombre,
        nombre_clase=nombre_clase,
        nombre_servicio=provider_key,  # se define por el proveedor seleccionado
        orden_servidor=orden_servidor,
        de=de,
        de_nombre=de_nombre,
        reply_to=reply_to,
        usuario=usuario,
        password=password,
        host=cred_data.get("host", ""),
        puerto=cred_data.get("port", ""),
        credenciales=encrypted
    )

    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        session.add(servidor)
        session.commit()
        session.refresh(servidor)
        typer.echo(f"✅ Servidor creado con ID {servidor.id}")

        # Crear asociación con la app
        app_servidor = MailAppServidor(
            id_app=id_app,
            id_servidor=servidor.id,
            tipo="M",  # M de Mail
            activo="S",
            orden_servidor=servidor.orden_servidor,
            created_at=datetime.utcnow()
        )
        session.add(app_servidor)
        session.commit()
        typer.echo(f"📩 Asociación con app creada en mail_app_servidores con ID {app_servidor.id}")


    if sql:
        insert_sql = f"""
INSERT INTO mail_servidores (
    nombre, charset, descripcion, nombre_clase, nombre_servicio, orden_servidor,
    de, de_nombre, reply_to, ip, puerto, host, usuario, password, credenciales
) VALUES (
    '{servidor.nombre}', 'utf8', NULL, '{servidor.nombre_clase}', '{servidor.nombre_servicio}', {servidor.orden_servidor},
    '{servidor.de}', '{servidor.de_nombre}', '{servidor.reply_to}', NULL, '{servidor.puerto}', '{servidor.host}',
    '{servidor.usuario}', '{servidor.password}', '{servidor.credenciales}'
);
"""
        print("\n--- SQL para copiar y pegar ---")
        print(insert_sql)


if __name__ == "__main__":
    app()
