from app.providers.assistro_provider import AssistroProvider

class WhatsAppService:

    def __init__(self, provider: AssistroProvider):
        self.provider = provider

    def enviar_mensaje(self, numero: str, mensaje: str, ruta_media: str | None = None):
        if not numero.startswith("34") and not numero.startswith("1"):
            raise ValueError("El número debe incluir prefijo país sin +")

        return self.provider.send_whatsapp(
            numero=numero,
            mensaje=mensaje,
            ruta_media=ruta_media
        )
