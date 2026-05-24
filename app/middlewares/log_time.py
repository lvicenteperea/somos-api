import datetime
import logging

from fastapi import Request

from app.config.db import get_db_manager
from app.models.log_time import LogTime

logger = logging.getLogger(__name__)


async def log_tiempos(request: Request, call_next):
    request_date = datetime.datetime.now()
    response = await call_next(request)

    end_time = datetime.datetime.now()
    duration = round((end_time.timestamp() - request_date.timestamp()) * 1000, 2)

    try:
        log_entry = LogTime(
            endpoint=request.url.path,
            request_date=request_date,
            duration=duration,
            ip=request.client.host if request.client else None,
            response_code=response.status_code,
        )

        db_manager = get_db_manager()
        with db_manager.get_session() as session:
            session.add(log_entry)
            session.commit()
            session.refresh(log_entry)

    except Exception as e:
        logger.debug("No se pudo registrar el tiempo de respuesta: %s", e)

    return response
