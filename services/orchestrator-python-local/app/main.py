import secrets
from datetime import datetime, timezone

import httpx
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def request_id() -> str:
    return f"req_{secrets.token_hex(6)}"


def write_error(code: str, message: str):
    return {
        "request_id": request_id(),
        "status": "error",
        "error": {
            "code": code,
            "message": message,
        },
        "meta": {
            "service": "orchestrator-python-local",
        },
    }


class SessionTransport(BaseModel):
    kind: str = "livekit"
    livekit_ws_url: str = "ws://localhost:7880"


class Session(BaseModel):
    session_id: str
    status: str
    mode: str
    avatar_id: str
    user_id: str | None = None
    metadata: dict[str, str] | None = None
    transport: SessionTransport
    created_at: str
    updated_at: str


class CreateSessionRequest(BaseModel):
    mode: str | None = None
    avatar_id: str | None = None
    user_id: str | None = None
    metadata: dict[str, str] | None = None


class UpdateSessionRequest(BaseModel):
    status: str | None = None
    avatar_id: str | None = None
    metadata: dict[str, str] | None = None


ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "created": {"ready", "closed"},
    "ready": {"active", "closed"},
    "active": {"closed"},
    "closed": set(),
}

SERVICE_ENDPOINTS = {
    "asr": "http://127.0.0.1:8101",
    "tts": "http://127.0.0.1:8102",
    "avatar": "http://127.0.0.1:8103",
    "llm": "http://127.0.0.1:8104",
}

LIVEKIT_WS_URL = "ws://localhost:7880"
SRS_RTC_BASE_URL = "http://localhost:1985"

sessions: dict[str, Session] = {}

app = FastAPI(title="orchestrator-python-local", version="0.1.0")


@app.middleware("http")
async def cors_middleware(request: Request, call_next):
    if request.method == "OPTIONS":
        from fastapi.responses import JSONResponse

        response = JSONResponse({"status": "ok"})
    else:
        response = await call_next(request)

    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    response.headers["Access-Control-Allow-Methods"] = "GET,POST,PATCH,OPTIONS"
    return response


@app.get("/healthz")
def healthz():
    return {
        "status": "ok",
        "service": "orchestrator-python-local",
        "time": now_iso(),
    }


@app.get("/v1/info")
def info():
    return {
        "service": "orchestrator-python-local",
        "contract_version": "v1",
        "stack": SERVICE_ENDPOINTS,
        "transport": {
            "livekit": LIVEKIT_WS_URL,
            "srs": SRS_RTC_BASE_URL,
        },
    }


@app.get("/v1/services/health")
async def services_health():
    result = []
    async with httpx.AsyncClient(timeout=2.0) as client:
        for name, base_url in SERVICE_ENDPOINTS.items():
            try:
                response = await client.get(f"{base_url}/healthz")
                result.append(
                    {
                        "name": name,
                        "base_url": base_url,
                        "healthy": 200 <= response.status_code < 300,
                        "status_code": response.status_code,
                    }
                )
            except Exception as exc:
                result.append(
                    {
                        "name": name,
                        "base_url": base_url,
                        "healthy": False,
                        "error": str(exc),
                    }
                )

    return {
        "request_id": request_id(),
        "status": "ok",
        "data": {
            "services": result,
        },
        "meta": {
            "service": "orchestrator-python-local",
        },
    }


@app.get("/v1/sessions")
def list_sessions():
    items = sorted(sessions.values(), key=lambda item: item.created_at, reverse=True)
    return {
        "request_id": request_id(),
        "status": "ok",
        "data": {
            "items": [item.model_dump() for item in items],
            "total": len(items),
        },
        "meta": {
            "service": "orchestrator-python-local",
        },
    }


@app.post("/v1/sessions", status_code=201)
def create_session(payload: CreateSessionRequest):
    session = Session(
        session_id=f"sess_{secrets.token_hex(8)}",
        status="created",
        mode=payload.mode or "text_chat",
        avatar_id=payload.avatar_id or "default-avatar",
        user_id=payload.user_id,
        metadata=payload.metadata or {},
        transport=SessionTransport(livekit_ws_url=LIVEKIT_WS_URL),
        created_at=now_iso(),
        updated_at=now_iso(),
    )
    sessions[session.session_id] = session
    return {
        "request_id": request_id(),
        "session_id": session.session_id,
        "status": "created",
        "data": {
            "session": session.model_dump(),
            "control_api": f"/v1/sessions/{session.session_id}",
        },
        "meta": {
            "service": "orchestrator-python-local",
        },
    }


@app.get("/v1/sessions/{session_id}")
def get_session(session_id: str):
    session = sessions.get(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail=write_error("not_found", "session not found"))
    return {
        "request_id": request_id(),
        "session_id": session.session_id,
        "status": "ok",
        "data": session.model_dump(),
        "meta": {
            "service": "orchestrator-python-local",
        },
    }


@app.patch("/v1/sessions/{session_id}")
def update_session(session_id: str, payload: UpdateSessionRequest):
    session = sessions.get(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail=write_error("not_found", "session not found"))

    if payload.status:
        if payload.status not in ALLOWED_TRANSITIONS:
            raise HTTPException(status_code=400, detail=write_error("bad_request", "invalid session status"))
        if payload.status != session.status and payload.status not in ALLOWED_TRANSITIONS[session.status]:
            raise HTTPException(status_code=400, detail=write_error("bad_request", "invalid session status transition"))
        session.status = payload.status

    if payload.avatar_id:
        session.avatar_id = payload.avatar_id
    if payload.metadata is not None:
        session.metadata = payload.metadata
    session.updated_at = now_iso()
    sessions[session_id] = session

    return {
        "request_id": request_id(),
        "session_id": session.session_id,
        "status": "ok",
        "data": session.model_dump(),
        "meta": {
            "service": "orchestrator-python-local",
        },
    }

