import datetime

from app.config.db import get_db_manager
from fastapi import FastAPI, Request
from app.models.log_time import LogTime

app = FastAPI()

@app.middleware("http")
async def log_tiempos(request: Request, call_next):
    # Middleware para registrar los tiempos de entrada, salida y duración total de cada solicitud.

    # Registrar el tiempo de entrada
    request_date = datetime.datetime.now()

    # Llamar al siguiente middleware o endpoint
    response = await call_next(request)
    return response

    # Registrar el tiempo de salida
    end_time = datetime.datetime.now()

    # Calcular la diferencia de tiempo en milisegundos
    duration = round((end_time.timestamp() - request_date.timestamp()) * 100000, 2)

    try:
        log_entry = LogTime(
            endpoint = request.url.path,
            request_date = request_date,
            duration = duration,
            ip = request.client.host,
            response_code = response.status_code
        )

        # Abrir sesión, añadir y confirmar
        db_manager = get_db_manager()
        with db_manager.get_session() as session:
            session.add(log_entry)
            session.commit()
            session.refresh(log_entry)

    except Exception as e:
        print(e)

    return response