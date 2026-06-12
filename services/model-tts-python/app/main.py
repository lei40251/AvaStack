from fastapi import FastAPI
from pydantic import BaseModel


class TTSRequest(BaseModel):
    session_id: str
    text: str
    voice_id: str | None = None


app = FastAPI(title="avastack-tts", version="0.1.0")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "avastack-tts"}


@app.get("/v1/info")
def info():
    # 服务元信息与运行时信息保持固定格式，便于编排层聚合。
    return {
        "service": "avastack-tts",
        "backend": "stub",
        "planned_backend": "cosyvoice2",
        "runtime": "cpu",
    }


@app.get("/v1/voices")
def voices():
    return {
        "items": [
            {"voice_id": "default-cn-female", "label": "Default Chinese Female"},
        ]
    }


@app.post("/v1/synthesize")
def synthesize(payload: TTSRequest):
    # 先返回稳定的包裹结构，后续由真实 TTS 后端填充音频结果。
    return {
        "request_id": "stub-request",
        "session_id": payload.session_id,
        "status": "ok",
        "data": {
            "audio_uri": None,
            "chunks": [],
        },
        "meta": {
            "service": "avastack-tts",
            "backend": "stub",
            "runtime": "cpu",
        },
    }
