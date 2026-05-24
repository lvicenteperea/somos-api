from fastapi import FastAPI, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from app.config.settings import settings
from app.exception.handlers import core_exception_handler
from app.middlewares.jwt_auth import JWTBearer
from app.middlewares.log_time import log_tiempos
from app.routers.backoffice import router as backoffice
from app.routers.mails import router as mails
from app.utils.call_db_procedure import CoreDatabaseException

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version="1.0",
    docs_url=None,
    redoc_url="/miredoc",
    openapi_url="/openapi.json",
)

app.middleware("http")(log_tiempos)
app.add_middleware(JWTBearer)

app.include_router(mails)
app.include_router(backoffice)

app.add_exception_handler(Exception, core_exception_handler)
app.add_exception_handler(HTTPException, core_exception_handler)
app.add_exception_handler(RequestValidationError, core_exception_handler)
app.add_exception_handler(CoreDatabaseException, core_exception_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.CORS_ALLOW_ORIGINS.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, log_level="info", reload=True)
