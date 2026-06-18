"""
AvaStack Avatar（数字人渲染）服务 stub。

当前为骨架实现，对外提供渲染任务创建接口（/v1/render）。
计划后续接入 MuseTalk 驱动数字人面部动画。

启动方式:
    uvicorn app.main:app --host 0.0.0.0 --port 8103
"""
from fastapi import FastAPI
from pydantic import BaseModel


class AvatarRenderRequest(BaseModel):
    """数字人渲染请求体"""
    session_id: str
    avatar_id: str           # 目标数字人形象 ID
    audio_uri: str | None = None     # 驱动音频地址
    transcript: str | None = None    # 对应的口播文本


app = FastAPI(title="avastack-avatar", version="0.1.0")


@app.get("/healthz")
def healthz():
    """存活探针，返回服务自身可用状态。"""
    return {"status": "ok", "service": "avastack-avatar"}


@app.get("/v1/info")
def info():
    """返回服务元信息与计划中的渲染模型。"""
    return {
        "service": "avastack-avatar",
        "backend": "stub",
        "planned_backend": "musetalk",
        "runtime": "cpu",
    }


@app.post("/v1/render")
def render(payload: AvatarRenderRequest):
    """创建数字人渲染任务。返回异步任务 ID，后续可通过该 ID 查询任务进度。"""
    return {
        "request_id": "stub-request",
        "session_id": payload.session_id,
        "status": "accepted",
        "data": {
            "render_job_id": "stub-render-job",
            "stream_key": None,
        },
        "meta": {
            "service": "avastack-avatar",
            "backend": "stub",
            "runtime": "cpu",
        },
    }
