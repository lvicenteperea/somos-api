"""
Tests unitarios para app/utils/logging.py → crea_log y _emit_python_log.

Cubre:
  - crea_log llama a call_db_procedure con los parámetros correctos
  - crea_log aplica valores por defecto cuando los parámetros opcionales no se pasan
  - crea_log trunca v_user a 45 caracteres
  - crea_log trunca v_tipo / v_accion a 1 carácter
  - crea_log trunca v_mysql_errno a 150 caracteres
  - crea_log nunca propaga excepción aunque falle la BBDD
  - crea_log emite al logger de Python cuando local_logger=True
  - crea_log NO emite al logger de Python cuando local_logger=False (por defecto)
  - _emit_python_log mapea tipo/acción al nivel correcto de logging

Para ejecutar:
    pytest app/tests/test_crea_log.py -s -v
"""

import asyncio
import logging
import os
import pytest
from unittest.mock import AsyncMock, MagicMock, patch, call


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


# ---------------------------------------------------------------------------
# Fixture: mock de get_db_manager con sesión fake
# ---------------------------------------------------------------------------

def _make_db_manager_mock():
    """Devuelve un mock de get_db_manager() que provee un context manager limpio."""
    fake_session = MagicMock()
    fake_session.commit = MagicMock()

    ctx_manager = MagicMock()
    ctx_manager.__enter__ = MagicMock(return_value=fake_session)
    ctx_manager.__exit__ = MagicMock(return_value=False)

    manager = MagicMock()
    manager.get_session = MagicMock(return_value=ctx_manager)

    mock_get_db_manager = MagicMock(return_value=manager)
    return mock_get_db_manager, fake_session


# ---------------------------------------------------------------------------
# Tests de crea_log
# ---------------------------------------------------------------------------

class TestCreaLog:

    def test_llama_al_procedimiento_correcto(self):
        """Verifica que se llama a w_somos_crea_log."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="test log", v_user="equinsa"))

        mock_proc.assert_awaited_once()
        _, kwargs = mock_proc.call_args
        assert kwargs["procedure_name"] == "w_somos_crea_log"

    def test_parametros_obligatorios_se_envian(self):
        """v_log y v_user llegan correctamente al procedimiento."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="mat=1234ABC | parking=P01", v_user="equinsa"))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_user"] == "equinsa"
        assert params["v_Log"] == "mat=1234ABC | parking=P01"

    def test_valores_por_defecto(self):
        """Cuando no se pasan opcionales, se usan los valores por defecto."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc, \
             patch.dict(os.environ, {"APP_ID": "1"}):
            run(crea_log(v_log="msg", v_user="test"))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_idApp"] == 1
        assert params["v_tipo"] == "A"
        assert params["v_accion"] == "D"
        assert params["v_MESSAGE_TEXT"] == "Inicializado"
        assert params["v_MYSQL_ERRNO"] == "somos_core"
        assert params["v_retNum"] == 0
        assert '"slug": "TEXTO_OK"' in params["v_retTxt"]

    def test_id_app_se_lee_de_env(self):
        """v_idApp se toma de la variable de entorno APP_ID cuando v_id_app=None."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc, \
             patch.dict(os.environ, {"APP_ID": "7"}):
            run(crea_log(v_log="msg", v_user="test", v_id_app=None))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_idApp"] == 7

    def test_id_app_parametro_tiene_prioridad_sobre_env(self):
        """v_id_app explícito sobreescribe APP_ID del entorno."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc, \
             patch.dict(os.environ, {"APP_ID": "99"}):
            run(crea_log(v_log="msg", v_user="test", v_id_app=42))  # 42 gana sobre 99

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_idApp"] == 42

    def test_v_user_truncado_a_45_caracteres(self):
        """v_user se trunca a 45 caracteres."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="msg", v_user="u" * 100))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert len(params["v_user"]) == 45

    def test_v_tipo_truncado_a_1_caracter(self):
        """v_tipo se trunca a 1 carácter."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="msg", v_user="test", v_tipo="ERROR"))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_tipo"] == "E"

    def test_v_accion_truncado_a_1_caracter(self):
        """v_accion se trunca a 1 carácter."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="msg", v_user="test", v_accion="DEBUG"))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_accion"] == "D"

    def test_v_mysql_errno_truncado_a_150_caracteres(self):
        """v_MYSQL_ERRNO se trunca a 150 caracteres para respetar VARCHAR(150) del SP."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="msg", v_user="test", v_mysql_errno="x" * 300))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert len(params["v_MYSQL_ERRNO"]) == 150

    def test_output_vars_son_retnum_y_rettxt(self):
        """output_vars debe incluir v_retNum y v_retTxt."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="msg", v_user="test"))

        _, kwargs = mock_proc.call_args
        assert "v_retNum" in kwargs["output_vars"]
        assert "v_retTxt" in kwargs["output_vars"]

    def test_hace_commit_de_la_sesion(self):
        """Después de llamar al SP, se hace commit de la sesión."""
        from app.utils.logging import crea_log

        mock_db_manager, fake_session = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock):
            run(crea_log(v_log="msg", v_user="test"))

        fake_session.commit.assert_called_once()

    def test_error_en_bbdd_no_propaga_excepcion(self):
        """Si la BBDD falla, crea_log no debe lanzar excepción al llamador."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            mock_proc.side_effect = Exception("DB caída")
            run(crea_log(v_log="msg", v_user="test"))  # no debe lanzar

    def test_error_en_bbdd_se_registra_en_logger(self):
        """Si la BBDD falla, el error debe quedar en el logger de Python."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc, \
             patch("app.utils.logging.logger") as mock_logger:
            mock_proc.side_effect = Exception("DB caída")
            run(crea_log(v_log="msg", v_user="test"))
            mock_logger.error.assert_called_once()
            args = mock_logger.error.call_args[0]
            assert "[crea_log]" in args[0]

    def test_local_logger_false_no_emite(self):
        """Con local_logger=False (por defecto), no se emite al logger Python."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock), \
             patch("app.utils.logging._emit_python_log") as mock_emit:
            run(crea_log(v_log="msg", v_user="test", local_logger=False))
            mock_emit.assert_not_called()

    def test_local_logger_true_emite(self):
        """Con local_logger=True, se llama a _emit_python_log."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock), \
             patch("app.utils.logging._emit_python_log") as mock_emit:
            run(crea_log(v_log="msg", v_user="test", local_logger=True))
            mock_emit.assert_called_once()

    def test_ret_txt_personalizado(self):
        """v_ret_txt se envía tal cual al procedimiento."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        ret = '{"slug": "ERR_ENTRADA", "txt_cli": "Error entrada"}'
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="msg", v_user="test", v_ret_txt=ret))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_retTxt"] == ret

    def test_message_text_traceback(self):
        """v_message_text (traceback) se pasa a v_MESSAGE_TEXT."""
        from app.utils.logging import crea_log

        mock_db_manager, _ = _make_db_manager_mock()
        tb = "Traceback (most recent call last):\n  File test.py line 1\nValueError: bad"
        with patch("app.utils.logging.get_db_manager", mock_db_manager), \
             patch("app.utils.logging.call_db_procedure", new_callable=AsyncMock) as mock_proc:
            run(crea_log(v_log="error grave", v_user="equinsa", v_tipo="E", v_accion="2", v_message_text=tb))

        _, kwargs = mock_proc.call_args
        params = dict(kwargs["ordered_params"])
        assert params["v_MESSAGE_TEXT"] == tb


# ---------------------------------------------------------------------------
# Tests de _emit_python_log
# ---------------------------------------------------------------------------

class TestEmitPythonLog:

    def test_tipo_E_emite_error(self):
        from app.utils.logging import _emit_python_log
        with patch("app.utils.logging.logger") as mock_logger:
            _emit_python_log("E", "2", "origen", "user", "msg", "Inicializado")
            mock_logger.error.assert_called_once()

    def test_tipo_A_emite_warning(self):
        from app.utils.logging import _emit_python_log
        with patch("app.utils.logging.logger") as mock_logger:
            _emit_python_log("A", "D", "origen", "user", "msg", "Inicializado")
            mock_logger.warning.assert_called_once()

    def test_accion_D_emite_debug(self):
        from app.utils.logging import _emit_python_log
        with patch("app.utils.logging.logger") as mock_logger:
            _emit_python_log("X", "D", "origen", "user", "msg", "Inicializado")
            mock_logger.debug.assert_called_once()

    def test_otros_emite_info(self):
        from app.utils.logging import _emit_python_log
        with patch("app.utils.logging.logger") as mock_logger:
            _emit_python_log("I", "0", "origen", "user", "msg", "Inicializado")
            mock_logger.info.assert_called_once()
