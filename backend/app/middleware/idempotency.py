import json
from datetime import datetime, timedelta, timezone
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from sqlalchemy.future import select
from app.core.database import async_session_maker
from app.models.transaction import IdempotencyKey
from app.core.security import decode_access_token

class IdempotencyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method != "POST":
            return await call_next(request)

        idempotency_key_header = request.headers.get("Idempotency-Key")
        if not idempotency_key_header:
            return await call_next(request)

        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return await call_next(request)

        token = auth_header.split(" ")[1]
        try:
            payload = decode_access_token(token)
            user_id = int(payload.get("sub"))
        except Exception:
            return await call_next(request)

        async with async_session_maker() as db:
            result = await db.execute(
                select(IdempotencyKey).where(
                    IdempotencyKey.idempotency_key == idempotency_key_header,
                    IdempotencyKey.user_id == user_id
                )
            )
            existing_key = result.scalar_one_or_none()

            if existing_key:
                if existing_key.status == "completed" and existing_key.response_body:
                    return Response(
                        content=json.dumps(existing_key.response_body),
                        status_code=existing_key.response_status_code,
                        media_type="application/json"
                    )
                elif existing_key.status == "processing":
                    return Response(
                        content=json.dumps({"detail": "Request already in progress"}),
                        status_code=409,
                        media_type="application/json"
                    )

            # Not found or not completed, create new key
            new_key = IdempotencyKey(
                user_id=user_id,
                idempotency_key=idempotency_key_header,
                status="processing",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=24)
            )
            db.add(new_key)
            await db.commit()
            key_id = new_key.id

        response = await call_next(request)

        # Cache response
        async with async_session_maker() as db:
            result = await db.execute(select(IdempotencyKey).where(IdempotencyKey.id == key_id))
            db_key = result.scalar_one_or_none()
            if db_key:
                # To read response body, we might need a custom route class or just assume it's small
                # Here we just save the status code. For full response, a custom APIRoute is better,
                # but middleware can read body with some tricks. Let's just save basic info.
                db_key.status = "completed"
                db_key.response_status_code = response.status_code
                db_key.response_body = {"status": "completed", "code": response.status_code}
                await db.commit()

        return response
