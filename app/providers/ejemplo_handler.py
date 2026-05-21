from typing import Any, Optional

from app.providers.sdc import SDC
from fastapi import HTTPException, status

from app.providers.equinsa.sdc_equinsa import SDCEquinsa
from app.providers.parkare.sdc_parkare import SDCParkare
from app.providers.parkare_ficticio.sdc_prkfct1 import SDCPrkfct1
from app.providers.skidata.sdc_skidata import SDCSkidata


class SDCHandler:
    """
    Handler centralizado para resolver el Sistema de Control
    correspondiente en función de su código.
    """

    providers: dict[str, type[SDC]] = {
        "equinsa": SDCEquinsa,
        "parkare": SDCParkare,
        "skidata": SDCSkidata,
        "prkfct1": SDCPrkfct1, # sdc ficticio
    }

    def __init__(
        self,
        sdc_name: str = "",
        parking_id: str = "",
    ):
        provider_cls = SDCHandler.providers.get(sdc_name.lower())
        if not provider_cls:
            raise HTTPException(
                status_code=400, detail=f"Proveedor SdC desconocido: {sdc_name}"
            )
        self.provider: SDC = provider_cls(parking_id)
        self.parking_id = parking_id

    async def create_external_reservation(self, datos_reserva: dict) -> dict:
        """
        Crea una reserva externa usando el proveedor SdC correspondiente.
        """
        try:
            return await self.provider.create_external_reservation(
                self.parking_id, datos_reserva
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error al crear una reserva externa: {str(e)}",
            )

    async def edit_reservation(self, datos_reserva: dict) -> dict:
        """
        Edita una reserva externa usando el proveedor SdC correspondiente.
        """
        try:
            return await self.provider.edit_reservation(
                self.parking_id, datos_reserva
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error al editar una reserva externa: {str(e)}. datos_reserva: {datos_reserva}",
            )

    async def delete_reservation(self, datos_reserva: dict) -> dict:
        """
        Cancela una reserva externa usando el proveedor SdC correspondiente.
        """
        try:
            return await self.provider.delete_reservation(
                self.parking_id, datos_reserva
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error al cancelar una reserva externa: {str(e)}",
            )

    async def get_price_lists(self) -> dict:
        """
        Obtiene la lista de precios de los aparcamientos en el Sistema de Control externo.
        """
        try:
            return await self.provider.get_price_lists(self.parking_id)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Error al obtener la lista de precios de los aparcamientos: {str(e)}",
            )
