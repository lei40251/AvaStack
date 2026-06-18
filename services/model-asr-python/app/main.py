"""
AvaStack ASR（语音识别）服务 stub。

当前为骨架实现，对外提供稳定的 HTTP 契约接口（/healthz、/v1/info、/v1/transcribe），
计划后续接入 SenseVoice 作为真实后端。

启动方式:
    uvicorn app.main:app --host 0.0.0.0 --port 8101
"""
from fastapi import FastAPI
from pydantic import BaseModel


class ASRRequest(BaseModel):
    """转写请求体"""
    session_id: str
    audio_uri: str | None = None
    mime_type: str | None = None


app = FastAPI(title="avastack-asr", version="0.1.0")


@app.get("/healthz")
def healthz():
    """存活探针，返回服务自身可用状态。"""
    return {"status": "ok", "service": "avastack-asr"}


@app.get("/v1/info")
def info():
    """返回服务元信息与计划中的后端模型。"""
    return {
        "service": "avastack-asr",
        "backend": "stub",
        "planned_backend": "sensevoice",
        "runtime": "cpu",
    }


@app.post("/v1/transcribe")
def transcribe(payload: ASRRequest):
    """转写音频为文本。当前返回 stub 占位，后续接入真实 SenseVoice 后端。"""
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
