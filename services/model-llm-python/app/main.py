import os

from fastapi import FastAPI
from pydantic import BaseModel


class ChatRequest(BaseModel):
    session_id: str
    message: str
    system_prompt: str | None = None


app = FastAPI(title="avastack-llm", version="0.1.0")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "avastack-llm"}


@app.get("/v1/info")
def info():
    # LLM 网关负责对接实际推理服务，但 prompt 归一化应留在这一层。
    return {
        "service": "avastack-llm",
        "backend": "stub",
        "planned_backend": "qwen-vllm",
        "runtime": "cpu",
        "upstream": os.getenv("VLLM_BASE_URL", "http://vllm:8000"),
    }


@app.post("/v1/chat")
def chat(payload: ChatRequest):
    # 当前返回 stub 响应，用来固定对上游编排层的接口契约。
    return {
        "request_id": "stub-request",
        "session_id": payload.session_id,
        "status": "ok",
        "data": {
            "text": "stub response",
        },
        "meta": {
            "service": "avastack-llm",
            "backend": "stub",
            "runtime": "cpu",
        },
    }
