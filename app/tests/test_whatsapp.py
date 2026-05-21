from app.providers.assistro_provider import AssistroProvider
from app.services.whatsapp import WhatsAppService
from app.handlers.whatsapp_handler import WhatsAppHandler

def test_envio_real_whatsapp():
    token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwcC5hc3Npc3Ryby5jby9wbGFuL3dhcHVzaC1wbHVzL2N1c3RvbSIsImlhdCI6MTc1OTMzNDIwNywiZXhwIjoxNzkwODcwMjA3LCJuYmYiOjE3NTkzMzQyMDcsImp0aSI6IllMZmpzbDlGZnZRRmxMdkwiLCJzdWIiOiIyNTQzIiwicHJ2IjoiMjNiZDVjODk0OWY2MDBhZGIzOWU3MDFjNDAwODcyZGI3YTU5NzZmNyIsInVzZXJfY29tcGFueV9pZCI6OTI0LCJ1c2VyX3B1c2hfcGx1c193ZWJob29rX2lkIjo3NTMsImN1cnJlbnRfd2ViaG9va19pZCI6MzQ4LCJwcm9kdWN0X2lkIjo1LCJpbnRlZ3JhdGlvbiI6ImN1c3RvbSJ9.0c29lPvqI2YXO0RVOkbwz_K7rzqReR84Cj-Y-VYufJk"

    provider = AssistroProvider(token)
    service = WhatsAppService(provider)
    handler = WhatsAppHandler(service)

    resultado = handler.enviar(
        numero="34666593085",
        mensaje="Prueba desde test con Clubö ✔️",
        ruta_media=None
    )

    print(resultado)

    assert resultado["ok"] is True
