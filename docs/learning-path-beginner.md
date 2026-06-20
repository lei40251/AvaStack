# AvaStack 小白学习路线

> 适用：前端背景、Docker 用过、其他技术了解。目标：能独立开发维护 AvaStack 全栈项目。

## 项目现状速览

```
你的舒适区                   需要学的
───────────                 ─────────
TypeScript  ✅              Python + FastAPI  🆕
Vue 3       ✅              Hono 后端框架     🆕
Tailwind    ✅              SQLite + Drizzle  🆕
Docker 基础 ✅              LiveKit + SRS     🆕（后期）
```

## 学习路线总览

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5
 上手跑通    学Hono+DB   学Python    接AI模型    实时+部署
 (1天)      (3天)       (5天)       (7天+)      (按需)
```

---

## Phase 1：把项目跑起来（1 天）

**目标：** 两个服务本地启动，能创建会话、看到管理后台页面。

**步骤：**

1. 启动 orchestrator-ts
```bash
cd services/orchestrator-ts
cp .env.example .env
npm install
npm run dev
# → http://localhost:8080/healthz 返回 JSON
```

2. 启动 admin-web
```bash
cd services/admin-web
npm install
npm run dev
# → http://localhost:4173 看到仪表盘
```

3. 在管理后台点"新建会话"，看列表出现数据

**检验标准：** 管理后台三个页面都能打开，新建会话后列表能刷新出来。

---

## Phase 2：搞懂 Hono + 数据库（3 天）

**核心问题：** 你现在看到的那些 API 是怎么实现的？

### Day 1：读懂 orchestrator-ts 的请求链路

打开 `services/orchestrator-ts/src/index.ts`，顺着调用链读下去：

```
index.ts
  → app.ts          （装配中间件和路由）
    → routes/sessions.ts   （POST/GET/PATCH /v1/sessions）
      → services/session-store.ts  （SQLite 增删改查）
        → services/db.ts          （数据库连接和建表）
      → state/state-machine.ts    （状态流转校验）
    → routes/services.ts  （下游健康检查）
      → services/downstream.ts    （发 HTTP 请求给 4 个 Python 服务）
```

**动手：** 用 curl 把 7 个 API 全部调一遍，看请求和响应长什么样。

### Day 2：Hono 基础

Hono 的 API 和 Express 很像，前端同学秒上手：

```typescript
// 一个最简 Hono 应用
import { Hono } from "hono";
const app = new Hono();

app.get("/hello", (c) => c.json({ msg: "hello" }));
app.post("/data", async (c) => {
  const body = await c.req.json();
  return c.json({ received: body }, 201);
});
```

**关键概念（30 分钟就能看完）：**
- 路由注册：`app.get/post/patch/delete`
- 路径参数：`c.req.param("id")`
- 请求体：`c.req.json()` / `c.req.valid("json")`（配合 Zod 校验）
- 响应：`c.json(data, status)`
- 中间件：`app.use("*", middleware)`

**资料：** [Hono 官方文档](https://hono.dev/docs) 的 "Getting Started" 和 "Routing" 两节就够了。

### Day 3：SQLite + Drizzle ORM

打开 `services/orchestrator-ts/src/services/db.ts` 和 `session-store.ts`。

**核心概念：**
- `sqliteTable("sessions", {...})` — 定义表结构
- `db.insert(sessions).values({...}).run()` — 插入
- `db.select().from(sessions).all()` — 查询全部
- `db.select().from(sessions).where(eq(sessions.id, id)).get()` — 单条查询
- `db.update(sessions).set({...}).where(...)` — 更新

**动手练习：** 在 `session-store.ts` 里加一个新方法 `deleteById(id)`，用 curl 测试。

**资料：** [Drizzle ORM 文档](https://orm.drizzle.team/docs/overview) 的 SQLite 部分。

**检验标准：** 能不看文档写出一个带 CRUD 的 Hono 路由 + Drizzle 存储。

---

## Phase 3：学 Python + FastAPI（5 天）

**核心问题：** 4 个 AI 模型服务都是 Python，你要能改、能加、能调。

### Day 1-2：Python 基础（只学需要的）

你不需要学成 Python 专家，只需要会用：

| 概念 | TS 对应 | 用在哪里 |
|------|---------|----------|
| `def foo(x):` | `function foo(x)` | 定义函数 |
| `dict` / `list` | 对象 / 数组 | JSON 数据处理 |
| `if/elif/else` | `if/else if/else` | 条件判断 |
| `for x in list:` | `for (x of list)` | 遍历 |
| `f"hello {name}"` | `` `hello ${name}` `` | 字符串拼接 |
| `try/except` | `try/catch` | 错误处理 |
| `import X` | `import X` | 导入模块 |
| `class Foo:` | `class Foo` | 类定义（少用） |

**资料：** Python 官方教程前 6 章（约 3 小时读完）→ https://docs.python.org/zh-cn/3/tutorial/

**动手：** 用 Python 写一个脚本，读取 JSON 文件，统计字段出现次数。

### Day 3：FastAPI 入门

打开 `services/model-llm-python/app/main.py`，看一个完整例子：

```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class ChatRequest(BaseModel):
    message: str

@app.get("/healthz")
def health():
    return {"status": "ok"}

@app.post("/v1/chat")
def chat(req: ChatRequest):
    # 目前是 stub，返回占位数据
    return {"reply": f"echo: {req.message}"}
```

**关键概念（2 小时）：**
- `@app.get/post` — 路由装饰器
- `BaseModel` — 请求体校验（和 Zod 一样）
- `return {...}` — 自动转 JSON
- `uvicorn` — 启动服务器（类似 `node index.js`）

**资料：** [FastAPI 官方教程](https://fastapi.tiangolo.com/zh/tutorial/first-steps/) 的前 5 节。

### Day 4-5：把 LLM stub 改成真的（Ollama 接入）

1. 装 Ollama：`ollama pull qwen2.5:0.5b`（小模型，CPU 就能跑）
2. 改 `model-llm-python/app/main.py`，把 stub 替换为真实调用：

```python
import httpx

@app.post("/v1/chat")
async def chat(req: ChatRequest):
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "http://localhost:11434/api/generate",
            json={"model": "qwen2.5:0.5b", "prompt": req.message, "stream": False}
        )
        return resp.json()
```

3. 在 admin-web 加一个对话测试页面，发送消息看 AI 回复。

**检验标准：** 能在管理后台输入一句话，收到 Qwen 的真实回复。

---

## Phase 4：接真实 AI 模型（7 天+）

按难度顺序逐个接入：

| 顺序 | 模型 | 技术 | 硬件要求 | 难度 |
|------|------|------|----------|------|
| 1 | LLM（Qwen） | Ollama API | CPU 可用 | 🟢 低 |
| 2 | ASR（SenseVoice） | FunASR 框架 | CPU 可用 | 🟡 中 |
| 3 | TTS（CosyVoice 2） | ModelScope | 建议 GPU | 🔴 高 |
| 4 | Avatar（MuseTalk） | 开源权重 | 需要 GPU | 🔴 高 |

每个模型接入的套路一样：
1. 在 `model-xxx-python/app/main.py` 里找到 stub 端点
2. 装对应的 Python 推理库
3. 替换 stub 代码为真实模型调用
4. 用 curl 验证 → 改前端页面展示结果

---

## Phase 5：实时 + 部署（按需）

| 主题 | 内容 | 时机 |
|------|------|------|
| LiveKit | WebRTC 房间管理、音视频流 | Phase 3 完成后 |
| SRS | RTMP/HLS 流媒体分发 | 有直播需求时 |
| Docker 深入 | 多阶段构建、Compose 网络、卷管理 | Phase 2 即可开始 |
| PostgreSQL | 替换 SQLite，Drizzle 驱动切换 | 准备上线时 |
| K8s | 容器编排、灰度发布 | 真正生产部署时 |

---

## 学习原则

1. **按需学，不要系统学。** Python 不用看完整个教程，学到能改 FastAPI 的 stub 就够了。LiveKit 不用现在学，等 LLM 跑通再说。

2. **改代码比看文档快。** 每个 Phase 都有动手环节——改 stub、加路由、接模型。改一行，跑一下，看结果。

3. **前端先，后端后，模型最后。** TypeScript 是舒适区，从这里开始往外扩。Hono 和 Vue 3 都是 TS，无切换成本。Python 只用在 4 个模型服务里，代码量很小。

4. **项目即教材。** 这个项目本身就是最好的学习材料——代码量小、结构清晰、注释中文。每个文件开头都有职责说明。
