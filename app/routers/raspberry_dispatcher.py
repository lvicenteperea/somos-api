# app/routers/raspberry_dispatcher.py
from fastapi import APIRouter, Request, Response, Depends, Query
from fastapi.responses import HTMLResponse
import os, hmac, hashlib, json
from fastapi import APIRouter, Request, HTTPException, Depends, Body

from app.services.raspberry_dispatcher_service import (
    get_raspberry_dispatcher,
    RaspberryDispatcherService,
)

router = APIRouter(tags=["raspberry-dispatcher"])

SECRET = os.getenv("NCHAN_TOKEN_SECRET", "dev_secret_change_me")
NCHAN_BASE = os.getenv("NCHAN_BASE", "http://localhost:8080")

# app/routers/raspberry_dispatcher.py
from urllib.parse import unquote
import logging
logger = logging.getLogger("raspberry-auth")

def _verify_token(channel_id: str, token: str) -> bool:
    mac = hmac.new(SECRET.encode(), channel_id.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(mac, token or "")

@router.get("/nchan/auth")
async def nchan_auth(
    request: Request,
    rd: RaspberryDispatcherService = Depends(get_raspberry_dispatcher),
):
    # 1) Preferimos query (FastAPI ya decodifica %3A -> :)
    q_id = request.query_params.get("id")
    q_tk = request.query_params.get("token")

    # 2) Si no hay query, tomamos headers y DECODIFICAMOS el id
    h_id_raw = request.headers.get("X-Channel-Id")
    h_tk     = request.headers.get("X-Token")
    h_id = unquote(h_id_raw) if h_id_raw else None

    channel_id = (q_id or h_id or "").strip()
    token      = (q_tk or h_tk or "").strip()

    logger.info("AUTH hit: raw_header_id=%r decoded_header_id=%r query_id=%r", h_id_raw, h_id, q_id)

    if not _verify_token(channel_id, token):
        logger.warning("AUTH 403: id=%r token(prefix)=%s", channel_id, token[:8])
        return Response(status_code=403)

    try:
        # Publica el “OK” al PROPIO canal (usa el mismo id canónico con :)
        await rd.send(channel_id, {"type": "default_html", "html": "<h1>OK</h1>"})
    except Exception as e:
        logger.info("publish handshake failed: %s", e)

    return Response(status_code=200)




# -------- TEST: página HTML con cliente WebSocket --------
@router.get("/raspberry/test", response_class=HTMLResponse)
async def raspberry_test_page(terminal_id: str = Query(..., description="ID del terminal")):
    channel = f"terminal:{terminal_id}"
    token = hmac.new(SECRET.encode(), channel.encode(), hashlib.sha256).hexdigest()

    html = f"""<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <title>Raspberry Test – Terminal {terminal_id}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 2rem; }}
    #log {{ white-space: pre-wrap; border: 1px solid #ddd; padding: 1rem; height: 240px; overflow: auto; }}
    button {{ padding: .6rem 1rem; margin-right: .5rem; }}
  </style>
</head>
<body>
  <h1>Test Raspberry – Terminal {terminal_id}</h1>
  <p>Canal: <code>{channel}</code></p>
  <div>
    <button id="btnConnect">Conectar</button>
    <button id="btnDisconnect" disabled>Desconectar</button>
    <input id="sendTerminal" value="{terminal_id}">
    <button id="btnSend" disabled>Enviar prueba</button>
  </div>
  <h3>Eventos</h3>
  <div id="log"></div>

<script>
(function() {{
  const CHANNEL_ID = {json.dumps(channel)};
  const TOKEN = {json.dumps(token)};
  const WS_BASE = {json.dumps(NCHAN_BASE)};
  // const WS_BASE = (location.protocol === 'https:' ? 'wss' : 'ws') + '://' + location.hostname + ':8080';
  const WS_URL = WS_BASE + '/sub?id=' + encodeURIComponent(CHANNEL_ID) + '&token=' + TOKEN;

  const logEl = document.getElementById('log');
  const btnConnect = document.getElementById('btnConnect');
  const btnDisconnect = document.getElementById('btnDisconnect');
  const btnSend = document.getElementById('btnSend');

  let ws = null;
  let reconnecting = false;

  function log(...args) {{
    const line = args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ');
    logEl.textContent += line + '\\n';
    logEl.scrollTop = logEl.scrollHeight;
  }}

  function connect() {{
    ws = new WebSocket(WS_URL);
    ws.onopen = () => {{
      log('[open]', WS_URL);
      btnConnect.disabled = true;
      btnDisconnect.disabled = false;
      btnSend.disabled = false;
    }};
    ws.onmessage = (ev) => {{
      let data = ev.data;
      try {{ data = JSON.parse(ev.data); }} catch {{}}
      log('[message]', data);
    }};
    ws.onerror = (ev) => {{
      log('[error]', ev.message || 'error');
    }};
    ws.onclose = (ev) => {{
      log(`[close] code=${{ev.code}} reason=${{ev.reason || ''}}`);
      btnConnect.disabled = false;
      btnDisconnect.disabled = true;
      btnSend.disabled = true;
      if (!reconnecting) {{
        reconnecting = true;
        setTimeout(() => {{ reconnecting = false; connect(); }}, 2000);
      }}
    }};
  }}

  btnConnect.addEventListener('click', connect);
  btnDisconnect.addEventListener('click', () => {{
    if (ws && ws.readyState === WebSocket.OPEN) ws.close(1000, 'cerrado por usuario');
  }});

  // Llama al endpoint de prueba para enviar HTML a este terminal
  btnSend.addEventListener('click', async () => {{
      const termInput = document.getElementById('sendTerminal');
      try {{
        const termId = (termInput.value || '').trim();
        if (!termId) {{
          log('[send-error]', 'Debes indicar un terminal_id en el campo de texto');
          return;
        }}
    
        const url = `/test/enviar/${{encodeURIComponent(termId)}}`;
        const res = await fetch(url, {{ method: 'POST' }});
        const json = await res.json();
        log('[send]', {{ url, response: json }});
      }} catch (e) {{
        log('[send-error]', e && e.message ? e.message : e);
      }}
    }});

  // Conecta automáticamente al cargar
  connect();
}})();
</script>
</body>
</html>"""
    return HTMLResponse(content=html)


# -------- TEST: enviar al terminal (parametrizado) --------
@router.post("/test/enviar/{terminal_id}")
async def test_enviar_param(
    terminal_id: str,
    content: str = Body(default="<h1>Hola Nchan</h1>", description="URL final de éxito"),
    type: str = Body(default="html", description="URL final de éxito"),
    miliseconds: int = Body(default=5000, description="ID del TPV a utilizar"),
    rd: RaspberryDispatcherService = Depends(get_raspberry_dispatcher),
):

    if type == "html":
        await rd.send_html(terminal_id, content, duration_ms=miliseconds)
    elif type == "default_html":
        await rd.send_default_html(terminal_id, content)
    elif type == "image":
        await rd.send_image(terminal_id, content, duration_ms=miliseconds)
    elif type == "video":
        await rd.send_video(terminal_id, content, duration_ms=miliseconds)

    return {"ok": True, "terminal_id": terminal_id}
