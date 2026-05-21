from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Configuración de la aplicación cargada desde variables de entorno (.env).

    URLs/hosts externos van al .env por portabilidad entre entornos.
    Rutas relativas internas tienen defaults razonables y se sobrescriben si es necesario.
    """

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", case_sensitive=True, extra="ignore"
    )

    RASPBERRY_DURATION_MS: int = 12000
    RASPBERRY_PARTNER_DURATION_MS: int = 5000
    BOOKING_EMAIL_NOTIFICATION: str = "lvicente@somosimaginales.com"
    TIMEZONE: str = "Europe/Madrid"
    DEVELOPMENT: str = "1"  # SAD = pre/staging | PROD = producción

settings = Settings()
