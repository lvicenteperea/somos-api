from app.services.whatsapp import WhatsAppService

class WhatsAppHandler:

    def __init__(self, service: WhatsAppService):
        self.service = service

    def enviar(self, numero: str, mensaje: str, ruta_media: str | None = None):
        return self.service.enviar_mensaje(numero, mensaje, ruta_media)
