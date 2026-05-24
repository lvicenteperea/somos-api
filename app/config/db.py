from contextlib import contextmanager
from functools import lru_cache
from typing import Any, Dict, Optional

from sqlmodel import SQLModel, Session, create_engine

from app.config.settings import settings


class DatabaseManager:
    """Gestiona el engine y las sesiones de base de datos."""

    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(DatabaseManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(
        self,
        host: str = "localhost",
        port: int = 3306,
        user: str = "root",
        password: str = "",
        database: str = "",
        pool_size: int = 5,
        pool_recycle: int = 3600,
        connect_args: Optional[Dict[str, Any]] = None,
    ):
        if self._initialized:
            return

        self.connection_string = (
            f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"
        )
        self.engine = create_engine(
            self.connection_string,
            echo=False,
            pool_size=pool_size,
            pool_recycle=pool_recycle,
            connect_args=connect_args or {},
        )
        self._initialized = True

    @classmethod
    def from_environment(cls):
        return cls(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            database=settings.DB_NAME,
            pool_size=settings.DB_POOL_SIZE,
            pool_recycle=settings.DB_POOL_RECYCLE,
        )

    def create_tables(self):
        SQLModel.metadata.create_all(self.engine)

    @contextmanager
    def get_session(self):
        session = Session(self.engine)
        try:
            yield session
        finally:
            session.close()

    def get_engine(self):
        return self.engine


@lru_cache
def get_db_manager():
    return DatabaseManager.from_environment()


def get_db():
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        yield session
