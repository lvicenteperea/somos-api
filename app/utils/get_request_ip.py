from fastapi import Request
import os
from dotenv import load_dotenv

load_dotenv()

def get_request_ip(request: Request) -> str:
    if request:
        x_forwarded_for = request.headers.get("X-Forwarded-For")
        if x_forwarded_for:
            # A veces este header puede contener varias IPs separadas por coma
            return x_forwarded_for.split(",")[0].strip()
        return request.client.host
    else:
        return os.getenv("PROJECT_IP", "127.0.0.1")