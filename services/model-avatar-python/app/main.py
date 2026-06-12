from fastapi import FastAPI
from pydantic import BaseModel


class AvatarRenderRequest(BaseModel):
    session_id: str
    avatar_id: str
    audio_uri: str | None = None
    transcript: str | None = None


app = FastAPI(title="avastack-avatar", version="0.1.0")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "avastack-avatar"}


@app.get("/v1/info")
def info():
    # 数字人渲染层后续最可能频繁替换，因此单独暴露清晰的模型边界。
    return {
        "service": "avastack-avatar",
        "backend": "stub",
        "planned_backend": "musetalk",
        "runtime": "cpu",
    }


@app.post("/v1/render")
def render(payload: AvatarRenderRequest):
    # 这里先定义渲染任务入口，不在骨架期绑定 MuseTalk 细节。
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
