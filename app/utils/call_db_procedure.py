from typing import Any, Dict, List, Tuple
from sqlalchemy import text
from sqlalchemy.orm import Session
import traceback
from fastapi import HTTPException, status
import json


# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
class CoreDatabaseException(HTTPException):
    def __init__(
        self, slug, log, txt_cli, status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
    ):
        self.slug = slug
        self.log = log
        self.text_cli = txt_cli
        self.status_code = status_code  # status.HTTP_500_INTERNAL_SERVER_ERROR,
        self.detail = txt_cli if txt_cli else log

    def to_dict(self, slug=None, log=None, txt_cli=None):
        return {
            "detail": self.detail,
            "slug": slug if slug else self.slug,
            "log": log if log else self.log,
            "text_cli": txt_cli if txt_cli else self.text_cli,
        }

    def __dict__(self):
        return {
            "detail": self.detail,
            "slug": self.slug,
            "log": self.log,
            "text_cli": self.text_cli,
        }

    def __str__(self):
        return f"{{'detail': {self.detail}, 'slug': {self.slug}, 'log': {self.log}, 'text_cli': {self.text_cli} }}"


# --------------------------------------------------------------------------------------
# Parseamos el texto que llega de la BBDD puede puede llegar de varias maneras.....
# --------------------------------------------------------------------------------------
def handle_error_text(proc_name: str, raw_text: str) -> HTTPException:
    try:
        # Intentar parsear como diccionario
        data = json.loads(raw_text)

        # Quitar comillas dobles escapadas si vienen así
        slug = data.get("slug", "")
        log = data.get("log", "")
        txt_cli = data.get("txt_cli", "")

        if log:
            print(f":: DDBB PROC ERROR IN {proc_name} log:: ({slug}) :: log: {log}")

        if txt_cli:
            print(
                f":: DDBB PROC ERROR IN {proc_name} txt_cli:: ({slug}) :: txt: {txt_cli}"
            )

        if slug == '"SIN_SLUG"' or slug == "SIN_SLUG":
            slug = txt_cli

        return CoreDatabaseException(slug, log, txt_cli)

    except (json.JSONDecodeError, TypeError):
        slug = "ERR_INTERNO"
        log = f":: DDBB PROC ERROR IN {proc_name} except:: Error general decodificando JSON de error"
        txt_cli = "ERR_INTERNO"
        print(log)
        return CoreDatabaseException(slug, log, txt_cli)
        # return HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Error interno")


import json
from textwrap import indent


async def exec_python_output(exec_data, db):
    """
    Ejecuta código recibido desde BBDD en un único bloque async y en el mismo contexto compartido.
    - Siempre asume que puede haber 'await' en el snippet.
    - Acepta str (JSON) o dict con {"execute": "..."} o {"execute": ["...", "..."]}.
    - El bloque tiene acceso a `db`. Imports/variables persisten entre líneas dentro del bloque.
    """
    # 1) Normaliza entrada a dict
    if isinstance(exec_data, str):
        data = json.loads(exec_data)
    elif isinstance(exec_data, dict):
        data = exec_data
    else:
        raise TypeError(f"exec_python_output: tipo no soportado: {type(exec_data)}")

    # 2) Normaliza 'execute' a lista de líneas
    exec_list = data.get("execute") or []
    if isinstance(exec_list, str):
        exec_list = [exec_list]

    # 3) Monta el bloque async con todas las líneas
    block_src = "\n".join(exec_list)
    wrapped = "async def __db_exec_block__():\n" + indent(block_src, "    ")

    # 4) Namespace (globals) compartido del bloque: acceso a db y builtins.
    #    Si quieres exponer módulos para no tener que importarlos en el snippet, añádelos aquí.
    shared_ctx = {
        "db": db,
        "__builtins__": __builtins__,
        # "asyncio": asyncio,
        # "os": os,
        # "json": json,
        # ... lo que veas útil
    }

    try:
        # 5) Compila y define el bloque en ese namespace
        code_obj = compile(wrapped, "<db-exec-async>", "exec")
        exec(code_obj, shared_ctx, shared_ctx)

        # 6) Ejecuta el bloque (await)
        coro = shared_ctx["__db_exec_block__"]()
        return await coro

    except Exception as e:
        print(f"[ERROR] exec_python_output: {e}")
        raise CoreDatabaseException(
            slug="ERR_INTERNO",
            log=f"Error interno al ejecutar código python en procedimiento. Exec Data: {str(exec_data)} - error: {str(e)}",
            txt_cli="Error interno",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
async def call_db_procedure(
    db,
    procedure_name: str,
    ordered_params: List[Tuple[str, Any]],
    output_vars: List[str],
) -> Dict[str, Any]:
    """
    Envuelve una llamada a call_db_procedure agrupando dinámicamente los parámetros
    en JSON de entrada y salida, y luego los desagrega tras la ejecución.

    Ejemplo:
        v_datos_entrada = { todos los parámetros de entrada }
                            Si una variable está en output_vars pero tiene valor (no None),
                            se incluye también en el JSON de entrada (v_datos_entrada).
        v_datos_salida  = { todos los parámetros de salida (inicialmente None) }

    Luego el procedimiento SQL recibe:
        CALL w_xxx(v_datos_entrada, v_datos_salida);

    Y al devolver los resultados, la función desglosa los valores de v_datos_salida.
    """

    try:
        # 1️⃣ Convertir lista de parámetros en dict
        params_dict = dict(ordered_params)

        # 2️⃣ Variables fijas estándar
        fixed_params = {
            "v_idApp": params_dict.get("v_idApp"),
            "v_user": params_dict.get("v_user"),
            "v_retNum": params_dict.get("v_retNum", 0),
            "v_retTxt": params_dict.get("v_retTxt", ""),
        }

        # 3️⃣ Separar dinámicamente las variables
        entrada_vars = {}
        salida_vars = {}

        for k, v in ordered_params:
            if k in fixed_params:
                continue

            if k in output_vars:
                # Si es de salida (OUT o INOUT)
                salida_vars[k] = v

                # Si tiene valor inicial, también la añadimos a la entrada (INOUT)
                if v is not None:
                    entrada_vars[k] = v
            else:
                # Es de entrada normal
                entrada_vars[k] = v

        # 4️⃣ Crear los JSON
        v_datos_entrada = json.dumps(entrada_vars, ensure_ascii=False)
        v_datos_salida = json.dumps(salida_vars, ensure_ascii=False)

        print(f"📥 [call_db_procedure_json] v_datos_entrada:\n{v_datos_entrada}")
        print(f"📤 [call_db_procedure_json] v_datos_salida inicial:\n{v_datos_salida}")

        # 5️⃣ Llamar al procedimiento agrupado
        res = await _call_db_procedure(
            db=db,
            procedure_name=procedure_name,
            ordered_params=[
                ("v_idApp", fixed_params["v_idApp"]),
                ("v_user", fixed_params["v_user"]),
                ("v_retNum", fixed_params["v_retNum"]),
                ("v_retTxt", fixed_params["v_retTxt"]),
                ("v_datos_entrada", v_datos_entrada),
                ("v_datos_salida", v_datos_salida),
            ],
            output_vars=["v_retNum", "v_retTxt", "v_datos_salida"],
        )

        # 6️⃣ Procesar respuesta
        ret_num = res.get("v_retNum", -99)
        ret_txt = res.get("v_retTxt", "Error desconocido")
        datos_salida_raw = res.get("v_datos_salida")

        # print(
        #     f"📦 [call_db_procedure_json] Resultado bruto v_datos_salida:\n{datos_salida_raw}"
        # )

        # 7️⃣ Decodificar JSON
        datos_salida = {}
        if datos_salida_raw:
            try:
                datos_salida = json.loads(datos_salida_raw)
            except Exception:
                print(
                    "[WARN] No se pudo decodificar v_datos_salida (no es JSON válido)."
                )

        # 8️⃣ Combinar resultados
        final_result = {"v_retNum": ret_num, "v_retTxt": ret_txt, **datos_salida}

        # Se ejecuta ya en call_db_procedure
        if datos_salida.get("v_exec_python"):
            print("   ---- EXEC ---->>>  ", datos_salida.get("v_exec_python"))
            await exec_python_output(datos_salida.get("v_exec_python"), db)

        print(f"✅ [call_db_procedure_json] Resultado final:\n{final_result}")
        return final_result

    except HTTPException as e:
        print(f"❌ [call_db_procedure_json] Error:\n{str(e)}")
        raise
    except Exception as e:
        print(f"❌ [ERROR] call_db_procedure_json({procedure_name}) → {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno al ejecutar {procedure_name}: {str(e)}",
        )

# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
async def call_db_procedure_no_exception(
    db,
    procedure_name: str,
    ordered_params: List[Tuple[str, Any]],
    output_vars: List[str],
    debug_print: bool = False,
) -> Dict[str, Any]:
    """
    Combina la lógica JSON de call_db_procedure_json (agrupa parámetros en
    v_datos_entrada / v_datos_salida) con el comportamiento "no exception" de
    call_db_procedure_no_exception (no lanza excepción ante v_retNum negativo,
    simplemente devuelve el resultado tal cual).
    """

    try:
        # 1️⃣ Convertir lista de parámetros en dict
        params_dict = dict(ordered_params)

        # 2️⃣ Variables fijas estándar
        fixed_params = {
            "v_idApp": params_dict.get("v_idApp"),
            "v_user": params_dict.get("v_user"),
            "v_retNum": params_dict.get("v_retNum", 0),
            "v_retTxt": params_dict.get("v_retTxt", ""),
        }

        # 3️⃣ Separar dinámicamente las variables
        entrada_vars = {}
        salida_vars = {}

        for k, v in ordered_params:
            if k in fixed_params:
                continue

            if k in output_vars:
                salida_vars[k] = v
                if v is not None:
                    entrada_vars[k] = v
            else:
                entrada_vars[k] = v

        # 4️⃣ Crear los JSON
        v_datos_entrada = json.dumps(entrada_vars, ensure_ascii=False)
        v_datos_salida = json.dumps(salida_vars, ensure_ascii=False)

        if debug_print:
            print(f"📥 [call_db_procedure_json_NE] v_datos_entrada:\n{v_datos_entrada}")
            print(
                f"📤 [call_db_procedure_json_NE] v_datos_salida inicial:\n{v_datos_salida}"
            )

        # 5️⃣ Llamar al procedimiento agrupado (sin excepción por retNum negativo)
        res = await _call_db_procedure_no_exception(
            db=db,
            procedure_name=procedure_name,
            ordered_params=[
                ("v_idApp", fixed_params["v_idApp"]),
                ("v_user", fixed_params["v_user"]),
                ("v_retNum", fixed_params["v_retNum"]),
                ("v_retTxt", fixed_params["v_retTxt"]),
                ("v_datos_entrada", v_datos_entrada),
                ("v_datos_salida", v_datos_salida),
            ],
            output_vars=["v_retNum", "v_retTxt", "v_datos_salida"],
            debug_print=debug_print,
        )

        # 6️⃣ Procesar respuesta
        ret_num = res.get("v_retNum", -99)
        ret_txt = res.get("v_retTxt", "Error desconocido")
        datos_salida_raw = res.get("v_datos_salida")

        if debug_print:
            print(
                f"📦 [call_db_procedure_json_NE] Resultado bruto v_datos_salida:\n{datos_salida_raw}"
            )

        # 7️⃣ Decodificar JSON
        datos_salida = {}
        if datos_salida_raw:
            try:
                datos_salida = json.loads(datos_salida_raw)
            except Exception:
                print(
                    "[WARN] call_db_procedure_json_NE: No se pudo decodificar v_datos_salida (no es JSON válido)."
                )

        # 8️⃣ Combinar resultados
        final_result = {
            "v_retNum": ret_num,
            "v_retTxt": ret_txt,
            **datos_salida,
        }

        if debug_print:
            print(f"✅ [call_db_procedure_json_NE] Resultado final:\n{final_result}")

        return final_result

    except Exception as e:
        print(f"❌ [ERROR] call_db_procedure_json_NE({procedure_name}) → {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"[ERROR] call_db_procedure_json_NE({procedure_name}). Fallo: {e}",
        )

# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
async def _call_db_procedure(
    db: Session,
    procedure_name: str,
    ordered_params: List[Tuple[str, Any]],
    output_vars: List[str],
    debug_print: bool = False,
) -> Dict[str, Any]:
    
    
    res: Dict[str, Any] = {}
    try:
        param_placeholders = []
        param_values = {}

        if debug_print:
            print(f"[DEBUG] Executing {procedure_name}")

        # Los procedimientos almacenados deben comenzar con "w_"
        if not procedure_name.startswith("w_"):
            procedure_name = f"w_{procedure_name}"

        for name, value in ordered_params:
            if name in output_vars:
                db.execute(text(f"SET @{name} = :value"), {"value": value})
                param_placeholders.append(f"@{name}")
                if debug_print:
                    print(f"SET @{name} = {repr(value)}")
            else:
                param_placeholders.append(f":{name}")
                param_values[name] = value

        placeholders_sql = ", ".join(param_placeholders)
        call_sql_text = f"CALL {procedure_name}({placeholders_sql})"

        if debug_print:
            print("\n[DEBUG] SQL CALL:")
            print(call_sql_text)
            print("[DEBUG] Parameters:")
            for k, v in param_values.items():
                print(f"  {k}: {repr(v)}")

        call_sql = text(call_sql_text)
        db.execute(call_sql, param_values)

        select_sql_text = "SELECT " + ", ".join(
            [f"@{var} as {var}" for var in output_vars]
        )
        if debug_print:
            print("\n[DEBUG] SQL SELECT OUT/INOUT:")
            print(select_sql_text)

        result = db.execute(text(select_sql_text))
        row = result.fetchone()

        if not row:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"No se pudo recuperar el resultado del procedimiento '{procedure_name}'",
            )

        res = dict(row._mapping)

        if res["v_retNum"] < 0:
            # Mapear códigos de error específicos a mensajes más detallados
            # error_message = res["v_retTxt"] if res["v_retTxt"] else f"Error desconocido al llamar a {procedure_name}"
            # error_message = parse_db_text(res["v_retTxt"])
            # print(f"[call_db_procedure] {procedure_name} ---> {type(res)} - {res}")
            db_exception = handle_error_text(procedure_name, res["v_retTxt"])

            # Comprobamos si es error 500 o 400
            if res["v_retNum"] <= -90:
                db_exception.status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
            else:
                db_exception.status_code = status.HTTP_400_BAD_REQUEST

            # Retornamos la excepcion de DDBB
            raise db_exception

        if (
            res.get("v_exec_python", "") != ""
            and res.get("v_exec_python", "") is not None
        ):
            if debug_print:
                print("   ---- EXEC ---->>>  ", res.get("v_exec_python"))
            await exec_python_output(res.get("v_exec_python"), db)

        # print(f"[call_db_procedure] {procedure_name} ---> {type(res)} - {res}")
        return res

    except HTTPException as e:
        if debug_print:
            print(
                f"[call_db_procedure] {procedure_name} HTTPException: {e.detail} ---> {type(res)} - {res}"
            )
        raise
    except Exception as e:
        print(f"[call_db_procedure] {procedure_name} Exception: Fallo: {e}")
        traceback.print_exc()
        db_exception = handle_error_text(
            procedure_name, f"[ERROR] call_db_procedure({procedure_name}). Fallo: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            # detail=f"[ERROR] call_db_procedure({procedure_name}). Fallo: {e}"
            detail=db_exception.detail,
        )


# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------
async def _call_db_procedure_no_exception(
    db: Session,
    procedure_name: str,
    ordered_params: List[Tuple[str, Any]],
    output_vars: List[str],
    debug_print: bool = False,
) -> Dict[str, Any]:
    try:
        param_placeholders = []
        param_values = {}

        for name, value in ordered_params:
            if name in output_vars:
                db.execute(text(f"SET @{name} = :value"), {"value": value})
                param_placeholders.append(f"@{name}")
                if debug_print:
                    print(f"SET @{name} = {repr(value)}")
            else:
                param_placeholders.append(f":{name}")
                param_values[name] = value

        placeholders_sql = ", ".join(param_placeholders)
        call_sql_text = f"CALL {procedure_name}({placeholders_sql})"

        if debug_print:
            print("\n[DEBUG] SQL CALL:")
            print(call_sql_text)
            print("[DEBUG] Parameters:")
            for k, v in param_values.items():
                print(f"  {k}: {repr(v)}")

        call_sql = text(call_sql_text)
        db.execute(call_sql, param_values)

        select_sql_text = "SELECT " + ", ".join(
            [f"@{var} as {var}" for var in output_vars]
        )
        if debug_print:
            print("\n[DEBUG] SQL SELECT OUT/INOUT:")
            print(select_sql_text)

        result = db.execute(text(select_sql_text))
        row = result.fetchone()

        if not row:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"No se pudo recuperar el resultado del procedimiento '{procedure_name}'",
            )

        res = dict(row._mapping)
        return res

    except Exception as e:
        print(f"[ERROR] call_db_procedure_NE({procedure_name}) fallo: {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"[ERROR] call_db_procedure_NE({procedure_name}). Fallo: {e}",
        )

