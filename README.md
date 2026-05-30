# Somos API

API base de SOMOS construida con FastAPI. El estado actual mantiene el nucleo comun del proyecto: conexion a MySQL, autenticacion JWT, registro de errores y envio de emails.

## Endpoints activos

- `POST /bo/auth`: autentica un usuario API y devuelve un bearer JWT.
- `POST /bo/mail/send`: registra un email y opcionalmente lo envia en el momento.
- `GET /openapi.json`: esquema OpenAPI.
- `GET /miredoc`: documentacion ReDoc.

## Configuracion

1. Crear un entorno virtual e instalar dependencias:

```bash
pip install -r requirements.txt
```

2. Crear `.env` tomando `.env.example` como base.

3. Arrancar la API:

```bash
uvicorn app.main:app --reload
 clear    ;  python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload 
```

## Tests

Los tests unitarios no deben depender de BBDD real ni proveedores externos:

```bash
pytest
```

Los tests marcados como integracion se saltan por defecto. Para ejecutarlos:

```bash
$env:RUN_INTEGRATION_TESTS="1"
pytest -m integration
```

## Estructura principal

- `app/main.py`: composicion de FastAPI, middleware, routers y handlers de excepcion.
- `app/config/`: settings y conexion a BBDD.
- `app/routers/`: endpoints HTTP activos.
- `app/services/`: logica de aplicacion.
- `app/mailing/`: proveedores y renderizado de email.
- `app/models/`: modelos SQLModel usados por los servicios activos.
- `app/utils/`: autenticacion, fechas, logging y llamadas a procedimientos.


Notas:
 - (Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned) ; (& c:\GitHub\somos-api\.venv\Scripts\Activate.ps1)