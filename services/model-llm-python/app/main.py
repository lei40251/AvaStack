"""
AvaStack LLM（大语言模型）网关 stub。

当前为骨架实现，对外提供统一的 chat 接口（/v1/chat），负责 prompt 归一化与上游编排层对接。
计划后续接入 Qwen + vLLM 作为推理后端。

启动方式:
    uvicorn app.main:app --host 0.0.0.0 --port 8104
"""
import os

from fastapi import FastAPI
from pydantic import BaseModel


class ChatRequest(BaseModel):
    """对话请求体"""
    session_id: str
    message: str
    system_prompt: str | None = None  # 可选的系统提示词


app = FastAPI(title="avastack-llm", version="0.1.0")


@app.get("/healthz")
def healthz():
    """存活探针，返回服务自身可用状态。"""
    return {"status": "ok", "service": "avastack-llm"}


@app.get("/v1/info")
def info():
    """返回服务元信息与上游推理服务地址。"""
    return {
        "service": "avastack-llm",
        "backend": "stub",
        "planned_backend": "qwen-vllm",
        "runtime": "cpu",
        "upstream": os.getenv("VLLM_BASE_URL", "http://vllm:8000"),
    }


@app.post("/v1/chat")
def chat(payload: ChatRequest):
    """处理对话请求，返回 LLM 生成的回复文本。当前为 stub 响应。"""
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
