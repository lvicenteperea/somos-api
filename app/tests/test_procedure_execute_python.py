# tests/test_exec_python_from_procedure.py
import os
import json
import pytest
from sqlalchemy import text

from app.config.db import get_db_manager
from app.utils.call_db_procedure import call_db_procedure, call_db_procedure_json

import tempfile
import os
import asyncio

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        os.getenv("RUN_INTEGRATION_TESTS") != "1",
        reason="requiere crear procedimientos en una BBDD real",
    ),
]

def _flag_path():
    return os.path.join(tempfile.gettempdir(), "pytest_exec_python")

@pytest.fixture(scope="function")
def db_session():
    manager = get_db_manager()
    with manager.get_session() as session:
        yield session

def _drop_procs(db):
    db.execute(text("DROP PROCEDURE IF EXISTS w_test_exec_python_normal"))
    db.execute(text("DROP PROCEDURE IF EXISTS w_test_exec_python_json"))
    db.execute(text("DROP PROCEDURE IF EXISTS w_test_exec_python_async_normal"))

def _create_procs(db):
    # Drop prev
    _drop_procs(db)

    # 1) NORMAL: v_exec_python (OUT/INOUT) -> escribe "normal"
    db.execute(text("""
    CREATE PROCEDURE w_test_exec_python_normal(
        IN v_idApp INT,
        IN v_user VARCHAR(100),
        INOUT v_retNum INT,
        INOUT v_retTxt LONGTEXT,
        INOUT v_exec_python LONGTEXT
    )
    BEGIN
        DECLARE vpy LONGTEXT;
        SET vpy = 'import tempfile, os; fp=os.path.join(tempfile.gettempdir(),"pytest_exec_python"); f=open(fp,"a"); f.write("normal"); f.write(chr(10)); f.close()';
        SET v_retNum = 0;
        SET v_retTxt = 'OK';
        SET v_exec_python = JSON_OBJECT('execute', JSON_ARRAY(vpy));
    END
    """))

    # 2) JSON: v_exec_python dentro de v_datos_salida -> escribe "json"
    db.execute(text("""
    CREATE PROCEDURE w_test_exec_python_json(
        IN v_idApp INT,
        IN v_user VARCHAR(100),
        INOUT v_retNum INT,
        INOUT v_retTxt LONGTEXT,
        IN v_datos_entrada LONGTEXT,
        INOUT v_datos_salida LONGTEXT
    )
    BEGIN
        DECLARE vpy LONGTEXT;
        SET vpy = 'import tempfile, os; fp=os.path.join(tempfile.gettempdir(),"pytest_exec_python"); f=open(fp,"a"); f.write("json"); f.write(chr(10)); f.close()';
        SET v_retNum = 0;
        SET v_retTxt = 'OK';
        SET v_datos_salida = JSON_OBJECT(
            'v_exec_python',
            JSON_OBJECT('execute', JSON_ARRAY(vpy))
        );
    END
    """))

    # 3) ASYNC NORMAL: v_exec_python (OUT/INOUT) -> bloque async con print
    #    Usamos \n escapados para definir un pequeño bloque async y await.
    db.execute(text("""
    CREATE PROCEDURE w_test_exec_python_async_normal(
        IN v_idApp INT,
        IN v_user VARCHAR(100),
        INOUT v_retNum INT,
        INOUT v_retTxt LONGTEXT,
        INOUT v_exec_python LONGTEXT
    )
    BEGIN
        DECLARE vpy LONGTEXT;
        SET vpy = 'import asyncio\\nasync def _t():\\n    print("ASYNC_OK")\\n    await asyncio.sleep(0)\\n\\nawait _t()';
        SET v_retNum = 0;
        SET v_retTxt = 'OK';
        SET v_exec_python = JSON_OBJECT('execute', JSON_ARRAY(vpy));
    END
    """))

    db.commit()

@pytest.mark.usefixtures("db_session")
def test_exec_python_via_procedures(db_session, capsys):
    # Limpieza previa de flag
    fp = _flag_path()
    try:
        if os.path.exists(fp):
            os.remove(fp)
    except Exception:
        pass
    _create_procs(db_session)

    try:
        # 1) Flujo NORMAL: se debe escribir "normal"
        res_normal = awaitable_call_db_procedure(
            db_session,
            procedure_name="test_exec_python_normal",  # helper añade w_
            ordered_params=[
                ("v_idApp", 1),
                ("v_user", "pytest"),
                ("v_retNum", 0),
                ("v_retTxt", ""),
                ("v_exec_python", None),
            ],
            output_vars=["v_retNum", "v_retTxt", "v_exec_python"],
        )
        assert res_normal["v_retNum"] == 0
        assert res_normal["v_retTxt"] == "OK"
        assert os.path.exists(fp)
        with open(fp, "r") as f:
            content = f.read()
        assert "normal" in content

        # 2) Flujo JSON: se debe escribir "json"
        res_json = awaitable_call_db_procedure_json(
            db_session,
            procedure_name="test_exec_python_json",
            ordered_params=[
                ("v_idApp", 1),
                ("v_user", "pytest"),
            ],
            output_vars=["v_exec_python"],
        )
        assert res_json["v_retNum"] == 0
        assert res_json["v_retTxt"] == "OK"
        with open(fp, "r") as f:
            content2 = f.read()
        assert "json" in content2

        # 3) Flujo ASYNC NORMAL: debe imprimir "ASYNC_OK" desde un método async awaited
        #    Capturamos stdout con capsys
        _ = awaitable_call_db_procedure(
            db_session,
            procedure_name="test_exec_python_async_normal",
            ordered_params=[
                ("v_idApp", 1),
                ("v_user", "pytest"),
                ("v_retNum", 0),
                ("v_retTxt", ""),
                ("v_exec_python", None),
            ],
            output_vars=["v_retNum", "v_retTxt", "v_exec_python"],
        )
        out = capsys.readouterr().out
        assert "ASYNC_OK" in out

    finally:
        _drop_procs(db_session)
        try:
            if os.path.exists(fp):
                os.remove(fp)
        except Exception:
            pass

# Helpers para ejecutar las funciones async desde pytest
import asyncio

def awaitable_call_db_procedure(db, procedure_name, ordered_params, output_vars):
    async def _runner():
        return await call_db_procedure(
            db=db,
            procedure_name=procedure_name,
            ordered_params=ordered_params,
            output_vars=output_vars,
            debug_print=False
        )
    return asyncio.get_event_loop().run_until_complete(_runner())

def awaitable_call_db_procedure_json(db, procedure_name, ordered_params, output_vars):
    async def _runner():
        return await call_db_procedure_json(
            db=db,
            procedure_name=procedure_name,
            ordered_params=ordered_params,
            output_vars=output_vars
        )
    return asyncio.get_event_loop().run_until_complete(_runner())
