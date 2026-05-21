#!/usr/bin/env python3
import asyncio
import sys
import os
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from app.config.db import get_db_manager
from app.services.mails import MailsService
from sqlalchemy import text
from dotenv import load_dotenv

load_dotenv(PROJECT_ROOT / ".env")

async def main():
    db_manager = get_db_manager()
    service = MailsService()
    try:
        with db_manager.get_session() as db:
            result = db.execute(text("SELECT id FROM mail_envios WHERE estado = 'P' LIMIT 100"))
            pending_ids = [row[0] for row in result.fetchall()]
            if not pending_ids:
                # log("No hay envíos pendientes.")
                print("No hay envíos pendientes.")
                return

            # log(f"Procesando {len(pending_ids)} envíos pendientes...")
            for envio_id in pending_ids:
                try:
                    await service.send_mail_process(db, envio_id)
                    # log(f"Envio {envio_id}: OK")
                    print(f"Envio {envio_id}: OK")
                except Exception as e:
                    # log(f"Envio {envio_id}: ERROR -> {e}")
                    print(f"Envio {envio_id}: ERROR -> {e}")

    except Exception as e:
        # log(f"Error en daemon de envío de mails: {e}")
        print(f"Error en daemon de envío de mails: {e}")

if __name__ == "__main__":
    asyncio.run(main())
