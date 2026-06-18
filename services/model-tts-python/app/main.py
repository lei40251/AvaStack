"""
AvaStack TTS（语音合成）服务 stub。

当前为骨架实现，对外提供语音合成（/v1/synthesize）与音色列表（/v1/voices）接口。
计划后续接入 CosyVoice 2 实现高质量语音合成。

启动方式:
    uvicorn app.main:app --host 0.0.0.0 --port 8102
"""
from fastapi import FastAPI
from pydantic import BaseModel


class TTSRequest(BaseModel):
    """语音合成请求体"""
    session_id: str
    text: str
    voice_id: str | None = None  # 可选，指定目标音色


app = FastAPI(title="avastack-tts", version="0.1.0")


@app.get("/healthz")
def healthz():
    """存活探针，返回服务自身可用状态。"""
    return {"status": "ok", "service": "avastack-tts"}


@app.get("/v1/info")
def info():
    """返回服务元信息与计划中的合成模型。"""
    return {
        "service": "avastack-tts",
        "backend": "stub",
        "planned_backend": "cosyvoice2",
        "runtime": "cpu",
    }


@app.get("/v1/voices")
def voices():
    """返回可用音色列表，供前端选择使用。"""
    return {
        "items": [
            {"voice_id": "default-cn-female", "label": "Default Chinese Female"},
        ]
    }


@app.post("/v1/synthesize")
def synthesize(payload: TTSRequest):
    """将文本合成为语音。当前返回 stub 占位，后续由真实 TTS 后端填充音频 URI。"""
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
