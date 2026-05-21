from datetime import datetime
from zoneinfo import ZoneInfo
from app.config.settings import settings

def ahora() -> datetime:
    """
    Devuelve la fecha/hora actual en la zona horaria configurada en settings,
    como datetime naive (sin tzinfo) para compatibilidad con la BBDD.
    
    Ejemplo: Europe/Madrid → en verano UTC+2, en invierno UTC+1.
    La BBDD recibe la hora local real, sin desfase.
    """
    tz = ZoneInfo(settings.TIMEZONE)
    return datetime.now(tz).replace(tzinfo=None)