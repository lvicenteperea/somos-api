import requests
import base64
from typing import Optional


class AssistroProvider:

    URL = "https://app.assistro.co/api/v1/wapushplus/single/message"

    def __init__(self, bearer_token: str, logger=None):
        if not bearer_token:
            raise ValueError("El token de ASSISTRO no puede estar vacío.")
        self.bearer_token = bearer_token
        self.logger = logger

    def send_whatsapp(
        self,
        numero: str,
        mensaje: str,
        ruta_media: Optional[str] = None
    ) -> dict:

        headers = {
            "Authorization": f"Bearer {self.bearer_token}",
            "Content-Type": "application/json"
        }

        media_list = []
        if ruta_media:
            with open(ruta_media, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("utf-8")
            media_list.append({
                "media_base64": b64,
                "file_name": ruta_media.split("/")[-1]
            })

        body = {
            "msgs": [
                {
                    "number": int(numero),
                    "message": mensaje,
                    "media": media_list
                }
            ]
        }

        try:
            resp = requests.post(self.URL, json=body, headers=headers)
            return {
                "status_code": resp.status_code,
                "ok": resp.ok,
                "data": resp.json() if resp.content else None
            }

        except Exception as e:
            if self.logger:
                self.logger.error(f"Error enviando WhatsApp ASSISTRO: {e}")
            return {"ok": False, "error": str(e)}
