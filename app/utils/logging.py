"""
app/utils/logging.py
--------------------
Utilidad centralizada de logging para Somos Core.

Permite grabar registros tanto en el sistema de logging estándar de Python
como en la base de datos a través del procedimiento almacenado `w_somos_crea_log`.

Uso básico
----------
    from app.utils.logging import crea_log

    # Registro de debug (entrada a un endpoint)
    await crea_log(
        db=db,
        v_log="mat=1234ABC | parking=P01 | accion=entrada",
        v_user="equinsa",
        v_mysql_errno="Inicio",  o "Salida" o "ex_controladas" u otro contexto
        v_ret_txt='{"slug": "TEXTO_OK", "txt_cli": "Inicio"}',
    )

    # Registro de error con traceback
    await crea_log(
        db=db,
        v_log=f"Error procesando entrada. mat={matricula}",
        v_user="equinsa",
        v_tipo="E",
        v_accion="2",
        v_mysql_errno="ex_controladas",
        v_message_text=traceback.format_exc(),
        v_ret_txt='{"slug": "ERR_ENTRADA", "txt_cli": "Error al procesar entrada"}',
    )

Parámetros de `w_somos_crea_log`
---------------------------------
v_idApp             : ID de la aplicación. Por defecto 1 (fijo en la función).
v_tipo              : 'A'=Aviso | 'E'=Error | 'I'=Incidencia | cualquier carácter.
v_accion            : 'D'=Debug | '0'=Ok | '1'=Parcial | '2'=Roto.
v_user              : Usuario o sistema origen (ej. "equinsa", "backoffice").
v_returned_sqlstate : Contexto del punto de ejecución (ej. "Entrada", "Salida",
                      "ex_controladas"). Por defecto "Sin error".
v_message_text      : Texto de detalle / traceback. Por defecto "Inicializado".
v_mysql_errno       : Nombre de la función/endpoint origen.
v_log               : Información de contexto libre (matrícula, parking, fechas…).
v_ret_txt           : JSON {"slug": "SLUG", "txt_cli": "texto"} para el cliente.
                      Por defecto '{"slug": "TEXTO_OK", "txt_cli": "Ok"}'.
"""

import inspect
import logging
import os
import traceback as tb_module
from typing import Optional

from sqlalchemy.orm import Session
from app.utils.call_db_procedure import call_db_procedure
from app.config.db import get_db_manager

# Logger estándar de Python (complementa al log en BBDD)
logger = logging.getLogger("somos.crea_log")

# ID de aplicación fijo (puede sobreescribirse por parámetro)
_DEFAULT_APP_ID = 1


# ──────────────────────────────────────────────────────────────────────────────
async def crea_log(
    db: Session = None,
    v_log: str = "",
    v_user: str = "sistema",
    *,
    v_tipo: str = "A",
    v_accion: str = "D",
    v_ret_txt: Optional[str] = None,
    v_mysql_errno: Optional[str] = None,
    v_returned_sqlstate: str = "Python",
    v_message_text: str = "Inicializado",
    v_id_app: Optional[int] = 1,
    local_logger: Optional[bool] = False,
) -> None:
    """
    Graba un registro de log en la base de datos llamando al procedimiento
    `w_somos_crea_log`, y de forma complementaria emite el mismo mensaje
    a través del sistema de logging estándar de Python.

    La función nunca lanza excepción hacia el llamador: si la llamada a BBDD
    falla, el error se captura y se imprime en el logger de Python para que
    no interrumpa el flujo principal.

    Parámetros
    ----------
    db : Session
        Sesión de SQLAlchemy activa.
    v_log : str
        Información de contexto libre. Es el campo más importante para el
        diagnóstico: matrícula, parking, fechas, valores relevantes…
    v_user : str
        Usuario o sistema que genera el log (ej. "equinsa", "backoffice").
    v_tipo : str, opcional
        Tipo de log: 'A'=Aviso | 'E'=Error | 'I'=Incidencia | otros.
        Por defecto 'A'.
    v_accion : str, opcional
        Acción: 'D'=Debug | '0'=Ok | '1'=A medias | '2'=Proceso roto.
        Por defecto 'D'.
    v_ret_txt : str, opcional
        JSON para el cliente: {"slug": "SLUG", "txt_cli": "texto"}.
        Si no se proporciona se usa '{"slug": "TEXTO_OK", "txt_cli": "Ok"}'.
    v_mysql_errno : str, opcional, se recoge automaticamente
        Nombre de la función/endpoint origen del log.
    v_returned_sqlstate : str, opcional
        Contexto del punto de ejecución: "Entrada", "Salida",
        "ex_controladas"… Por defecto "Sin error".
    v_message_text : str, opcional
        Detalle textual / traceback. Por defecto "Inicializado".
    v_id_app : int, opcional
        ID de la aplicación. Si no se proporciona se lee de la variable de
        entorno APP_ID; si tampoco existe, se usa 1.
    """

    id_app: int = v_id_app or int(os.getenv("APP_ID", _DEFAULT_APP_ID))
    ret_txt: str = v_ret_txt or '{"slug": "TEXTO_OK", "txt_cli": "Ok"}'
    mysql_errno: str = v_mysql_errno or "somos_core"

    try:
        if v_returned_sqlstate:
            v_returned_sqlstate = f"{inspect.currentframe().f_back.f_code.co_name}@{v_returned_sqlstate}"
        else:
            v_returned_sqlstate = f"{inspect.currentframe().f_back.f_code.co_name}@Python"

        # Enriquecer v_log con el nombre de la función origen y el contexto de ejecución
        if local_logger:
            _emit_python_log(v_tipo, v_accion, mysql_errno, v_user, f"[{mysql_errno}][{v_returned_sqlstate or 'Sin error'}] {v_log or ''}", v_message_text)

        db_manager = get_db_manager()
        with db_manager.get_session() as log_db:
            await call_db_procedure(
                db=log_db,
                procedure_name="w_somos_crea_log",
                ordered_params=[
                    ("v_idApp",             id_app),
                    ("v_tipo",              (v_tipo[:1] if v_tipo else "A")),
                    ("v_accion",            (v_accion[:1] if v_accion else "D")),
                    ("v_user",              (v_user or "")[:45]),
                    ("v_RETURNED_SQLSTATE", v_returned_sqlstate[:150]),
                    ("v_MESSAGE_TEXT",      (v_message_text or "Inicializado")[:4000]),
                    ("v_MYSQL_ERRNO",       (mysql_errno or "somos_core")[:150]),
                    ("v_Log",               v_log),
                    ("v_retNum",            0),
                    ("v_retTxt",            ret_txt),
                ],
                output_vars=["v_retNum", "v_retTxt"],
            )
            log_db.commit()
    except Exception:
        # El log en BBDD nunca debe romper el flujo principal
        logger.error(
            "[crea_log] Error al grabar en BBDD. Log no guardado en BBDD. "
            "v_log=%s | v_user=%s | v_tipo=%s | exc=%s",
            v_log,
            v_user,
            v_tipo,
            tb_module.format_exc(),
        )

# ──────────────────────────────────────────────────────────────────────────────
def _emit_python_log(
    tipo: str,
    accion: str,
    origen: str,
    user: str,
    v_log: str,
    message_text: str,
) -> None:
    """Mapea el tipo/acción al nivel de logging estándar de Python y emite."""
    mensaje = f"[{origen}] user={user} | accion={accion} | {v_log}"
    if message_text and message_text != "Inicializado":
        mensaje += f" | detail={message_text}"

    if tipo == "E":
        logger.error(mensaje)
    elif tipo == "A":
        logger.warning(mensaje)
    elif accion == "D":
        logger.debug(mensaje)
    else:
        logger.info(mensaje)


