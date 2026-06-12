from fastapi import FastAPI
from pydantic import BaseModel


class ASRRequest(BaseModel):
    session_id: str
    audio_uri: str | None = None
    mime_type: str | None = None


app = FastAPI(title="avastack-asr", version="0.1.0")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "avastack-asr"}


@app.get("/v1/info")
def info():
    # 先把服务契约固定成统一结构，后续再替换为真实 SenseVoice 后端。
    return {
        "service": "avastack-asr",
        "backend": "stub",
        "planned_backend": "sensevoice",
        "runtime": "cpu",
    }


@app.post("/v1/transcribe")
def transcribe(payload: ASRRequest):
    # 当前阶段仅保留明确的输入输出边界，不在骨架期引入真实模型依赖。
    return {
        "request_id": "stub-request",
        "session_id": payload.session_id,
        "status": "ok",
        "data": {
            "text": "",
            "segments": [],
        },
        "meta": {
            "service": "avastack-asr",
            "backend": "stub",
            "runtime": "cpu",
        },
    }
