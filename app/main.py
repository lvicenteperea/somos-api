# Lo siguiente:
#     utilizar los middleware


# uvicorn app.main:app --reload
# python -m uvicorn app.main:app --reload
# uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

from fastapi import FastAPI, HTTPException
import os
from pathlib import Path
from dotenv import load_dotenv

from fastapi.middleware.cors import CORSMiddleware

from app.middlewares.log_time import log_tiempos

# from app.api.routes import router as api_router

from app.routers.mails import router as mails
from app.routers.backoffice import router as backoffice

from app.docs_auth import setup_docs_auth
from app.utils.openapi_security import add_basic_auth_openapi
from fastapi.exceptions import RequestValidationError
from app.utils.call_db_procedure import CoreDatabaseException
from app.exception.handlers import core_exception_handler

from app.services.ejecutor.ejecutor_servicios import registra_all_services





# from app.api.routes.email_router import router as email_router
# from app.api.routes.sdc.equinsa_router import router as equinsa_router
# from app.api.routes.skidata_router import router as skidata_router
#
#
# from app.middleware.auth import AuthMiddleware
# import json
#
#
# from app.exceptions import http_exception_handler, json_decode_error_handler, generic_exception_handler, mi_exception_handler, type_error_handler, validation_exception_handler
# from app.config.settings import settings
# from app.utils.mis_excepciones import MiException
# from app.middleware.log_tiempos_respuesta import log_tiempos_respuesta

# -----------------------------------------------------------------------------------------------
# FASTAPI
# -----------------------------------------------------------------------------------------------
app = FastAPI(
    title=os.getenv("PROJECT_NAME", "SOMOS"),  # settings.PROJECT_NAME,
    description="Documentación de mi API con FastAPI",
    version="1.0",
    docs_url=None,  # Usamos /docs personalizado con auth
    redoc_url="/miredoc",
    openapi_url="/openapi.json",  # Necesario para que ReDoc funcione
)

SubFastAPI = FastAPI

registra_all_services() # Registramos los servicios disponibles para ejecución dinámica

# -----------------------------------------------------------------------------------------------
# Obtener el directorio raíz del proyecto (un nivel arriba de 'app')
# Cargar .env desde el directorio raíz
# -----------------------------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(os.path.join(BASE_DIR, ".env"))


# -----------------------------------------------------------------------------------------------
# MIDDLEWARES
# -----------------------------------------------------------------------------------------------
# Importar y registrar los middlewares
from app.middlewares.jwt_auth import JWTBearer
from app.middlewares.bip_drive_auth import BipDriveAuthMiddleware

app.middleware("http")(log_tiempos)
app.add_middleware(JWTBearer)
app.add_middleware(BipDriveAuthMiddleware)

# -----------------------------------------------------------------------------------------------
# RUTAS
# -----------------------------------------------------------------------------------------------
# app.include_router(api_router)
app.include_router(mails)
app.include_router(backoffice)

# Creamos sub-apps específicos para nuestros sistemas de control
add_basic_auth_openapi(elparking_app, title="ElParking API")

# -----------------------------------------------------------------------------------------------
# DOCS AUTH - Configurar autenticación para la documentación
# -----------------------------------------------------------------------------------------------
# setup_docs_auth(
#     app,
#     mounted_apps=[
#         ("/elparking", elparking_app),
#         ("/equinsa", equinsa_app),
#         ("/skidata", skidata_app),
#         ("/parkare", parkare_app),
#     ],
# )

# -----------------------------------------------------------------------------------------------
# EXCEPTION HANDLERS
# -----------------------------------------------------------------------------------------------
app.add_exception_handler(Exception, core_exception_handler)
app.add_exception_handler(HTTPException, core_exception_handler)
app.add_exception_handler(RequestValidationError, core_exception_handler)
app.add_exception_handler(CoreDatabaseException, core_exception_handler)

# -----------------------------------------------------------------------------------------------
# CORS
# -----------------------------------------------------------------------------------------------
# Configurar CORS para permitir peticiones con cabeceras de autenticación
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, restringe esto a dominios específicos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

"""
Este bloque de código se usa para iniciar la aplicación FastAPI utilizando uvicorn 
como servidor cuando ejecutas directamente el script Python. 
Es un método estándar para lanzar aplicaciones web con FastAPI y asegurar que el servidor 
web esté escuchando en el puerto y dirección IP correctos, con la configuración de logging adecuada.
"""
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info", reload=True)
