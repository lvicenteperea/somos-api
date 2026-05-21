# app/providers/sdc.py

from abc import ABC, abstractmethod
from typing import Any, Dict


class SDC(ABC):
    """
    Interfaz base para todos los Sistemas de Control (SdC).
    Cada implementación concreta (Equinsa, Parkare, etc.)
    debe cumplir este contrato.
    """

    def __init__(self, config: Dict[str, Any] | None = None):
        self.config = config or {}

    @abstractmethod
    def create_external_reservation(
        self, parking_id: str, datos_reserva: Dict[str, Any]
    ) -> Any:
        """
        Crea una reserva en el Sistema de Control externo.
        """
        pass

    @abstractmethod
    def edit_reservation(self, parking_id: str, datos_reserva: Dict[str, Any]) -> Any:
        """
        Cancela una reserva en el Sistema de Control externo.
        """
        pass

    @abstractmethod
    def delete_reservation(self, parking_id: str, datos_reserva: Dict[str, Any]) -> Any:
        """
        Cancela una reserva en el Sistema de Control externo.
        """
        pass

    @abstractmethod
    def get_reserva(self, parking_id: str, datos_reserva: Dict[str, Any]) -> Any:
        """
        Consulta una reserva en el Sistema de Control externo.
        """
        raise NotImplementedError

    @abstractmethod
    def get_price_lists(self, parking_id: str) -> Any:
        """
        Obtiene la lista de precios de los aparcamientos.
        """
        raise NotImplementedError
