import asyncio
import time
from app.config.db import get_db_manager
from app.services.mails import MailsService
from sqlalchemy import text

def daemon_loop():
    db_manager = get_db_manager()
    service = MailsService()

    while True:
        try:
            with db_manager.get_session() as db:
                result = db.execute(
                    text("SELECT id FROM mail_envios WHERE estado = 'P' LIMIT 100")
                )
                pending_ids = [row[0] for row in result.fetchall()]
                for envio_id in pending_ids:
                    asyncio.run(service.send_mail_process(db, envio_id))
        except Exception as e:
            print(f"Error en daemon de envío de mails: {e}")

        time.sleep(300)  # 5 minutos

if __name__ == "__main__":
    daemon_loop()
