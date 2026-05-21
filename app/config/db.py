from sqlmodel import SQLModel, Session, create_engine
from typing import Optional, Dict, Any
import os
from contextlib import contextmanager
from functools import lru_cache


class DatabaseManager:
    """
    Clase para gestionar la conexión a la base de datos MySQL en una aplicación FastAPI.
    Implementa un patrón singleton para mantener una única instancia de conexión.
    """
    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(DatabaseManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self,
                 host: str = "localhost",
                 port: int = 3306,
                 user: str = "root",
                 password: str = "",
                 database: str = "",
                 pool_size: int = 5,
                 pool_recycle: int = 3600,
                 connect_args: Optional[Dict[str, Any]] = None):
        # Evitar reinicializar si ya está inicializado (para el singleton)
        if self._initialized:
            return

        self.host = host
        self.port = port
        self.user = user
        self.password = password
        self.database = database
        self.pool_size = pool_size
        self.pool_recycle = pool_recycle
        self.connect_args = connect_args or {}

        # Construir la URL de conexión
        self.connection_string = f"mysql+pymysql://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}"

        # Crear el engine
        self.engine = create_engine(
            self.connection_string,
            echo=False,  # Cambiar a True para debugging
            pool_size=self.pool_size,
            pool_recycle=self.pool_recycle,
            connect_args=self.connect_args
        )

        self._initialized = True

    @classmethod
    def from_environment(cls):
        """
        Crea una instancia usando variables de entorno:
        - DB_HOST
        - DB_PORT
        - DB_USER
        - DB_PASSWORD
        - DB_NAME
        - DB_POOL_SIZE (opcional)
        - DB_POOL_RECYCLE (opcional)
        """
        return cls(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "3306")),
            user=os.getenv("DB_USER", "root"),
            password=os.getenv("DB_PASSWORD", ""),
            database=os.getenv("DB_NAME", ""),
            pool_size=int(os.getenv("DB_POOL_SIZE", "5")),
            pool_recycle=int(os.getenv("DB_POOL_RECYCLE", "3600"))
        )

    def create_tables(self):
        """Crea todas las tablas definidas en los modelos SQLModel."""
        SQLModel.metadata.create_all(self.engine)

    @contextmanager
    def get_session(self):
        """
        Proporciona un contexto de sesión para operaciones en la base de datos.
        Ejemplo de uso:
            with db_manager.get_session() as session:
                session.add(some_model)
                session.commit()
        """
        session = Session(self.engine)
        try:
            yield session
        finally:
            session.close()

    def get_engine(self):
        """Retorna el engine de SQLAlchemy."""
        return self.engine


# Función para obtener una instancia única del gestor de base de datos
@lru_cache
def get_db_manager():
    """
    Función que retorna una única instancia cacheada del DatabaseManager.
    Para usar con FastAPI como dependencia.
    """
    return DatabaseManager.from_environment()


# Función para obtener una sesión como dependencia en FastAPI
def get_db():
    """
    Dependencia para inyectar una sesión de base de datos en los endpoints de FastAPI.
    Ejemplo de uso:
        @app.get("/items/")
        def read_items(db: Session = Depends(get_db)):
            return db.query(Item).all()
    """
    db_manager = get_db_manager()
    with db_manager.get_session() as session:
        yield session