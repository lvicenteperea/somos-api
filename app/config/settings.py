from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    PROJECT_NAME: str = "SOMOS"
    PROJECT_DESCRIPTION: str = "Documentacion de la API SOMOS"
    APP_ID: int = 1
    SOMOS_SLUG: str = "somos"

    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = ""
    DB_NAME: str = ""
    DB_POOL_SIZE: int = 5
    DB_POOL_RECYCLE: int = 3600

    JWT_SECRET_KEY: str = "tu_clave_secreta_muy_segura_aqui"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    CORS_ALLOW_ORIGINS: str = "*"
    MAIL_MEDIA_PATH: str = "app/media/mail"
    TICKET_MEDIA_PATH: str = "app/media/tickets"
    TICKET_MAX_IMAGE_MB: int = 10
    NOTIFY_EMAILS: str = ""
    URL_PWA: str = "http://localhost"
    API_PAYMENTS_KEY: str = ""
    TIMEZONE: str = "Europe/Madrid"
    DEVELOPMENT: bool = True


settings = Settings()
