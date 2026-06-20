# AvaStack 技术栈改造设计文档

> 日期：2026-06-20  
> 状态：已确认  
> 作者：Jett + ZCode

---

## 一、背景与目标

### 1.1 当前状态

AvaStack 处于 Stage 0/1（架构骨架阶段），所有服务已定义但返回占位数据：
- 9 个 Docker 服务已配置可运行
- AI 模型服务（ASR/TTS/Avatar/LLM）尚未接入真实模型
- 调度服务（Go）和后台（TS 原生 DOM）代码量均小

### 1.2 团队情况

- 前端背景为主
- Docker 有使用基础
- 其他技术（Go、Python、LiveKit、SRS）均为了解水平
- 目标是全功能产品级交付

### 1.3 改造目标

1. **降低语言壁垒**：3 种语言 → 2 种，前端团队在舒适区内开发
2. **保持产品级架构**：Docker、LiveKit、SRS 等基础设施保留
3. **前后端类型共享**：消除手写两份契约的维护负担
4. **渐进增强**：开发期简单 → 生产期强化的平滑过渡路径

---

## 二、改造对照总览

| 组件 | 当前 | 改造后 | 操作 |
|------|------|--------|------|
| 调度服务 | Go 纯标准库 | TypeScript + Hono | 🔄 重写 |
| 管理后台 | TypeScript 原生 DOM | Vue 3 + Nuxt 3 | 🔄 重写 |
| AI 服务 ×4 | Python + FastAPI | 不变 | ✅ 保留 |
| 容器编排 | Docker Compose 9 服务 | 9 服务（替换 2 个） | ✅ 兼容 |
| 实时音视频 | LiveKit（已配置） | 不变 | ✅ 保留 |
| 流媒体 | SRS（已配置） | 不变 | ✅ 保留 |
| LLM 推理 | vLLM（远期规划） | Ollama（开发过渡）→ vLLM（生产） | 🔄 渐进 |
| 持久化 | 无（in-memory map） | SQLite（开发）→ PostgreSQL（生产） | 🆕 新增 |
| 类型契约 | 各服务自行维护 | `contracts.ts` 单一源，前后端共享 | 🆕 改进 |

---

## 三、完整目录结构

```
services/
├── orchestrator-ts/          # 🔄 新增：调度服务（TypeScript + Hono）
│   ├── src/
│   │   ├── index.ts
│   │   ├── app.ts
│   │   ├── config/env.ts
│   │   ├── routes/           # health / info / sessions / services
│   │   ├── services/         # downstream / session-store
│   │   ├── state/            # state-machine
│   │   ├── types/            # contracts.ts（前后端共享）
│   │   └── middleware/       # cors / request-id / error-handler
│   ├── drizzle/migrations/
│   ├── package.json
│   ├── tsconfig.json
│   └── Dockerfile
│
├── admin-web/                # 🔄 重写：管理后台（Vue 3 + Nuxt 3）
│   ├── pages/                # index / sessions / services
│   ├── components/           # layout / dashboard / sessions / services
│   ├── composables/          # useApi / usePolling
│   ├── types/                # 引用 orchestrator-ts 的 contracts.ts
│   ├── package.json
│   ├── nuxt.config.ts
│   └── Dockerfile
│
├── model-asr-python/         # ✅ 保留：语音识别（Python + FastAPI）
│   ├── app/main.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── model-tts-python/         # ✅ 保留：语音合成（Python + FastAPI）
│   ├── app/main.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── model-avatar-python/      # ✅ 保留：数字人渲染（Python + FastAPI）
│   ├── app/main.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── model-llm-python/         # ✅ 保留：大模型对话（Python + FastAPI）
│   ├── app/main.py
│   ├── requirements.txt
│   └── Dockerfile
│
└── orchestrator-go/          # 📦 保留不动（对照参考，重构完成后移除）
    ├── cmd/api/main.go
    ├── internal/...
    ├── go.mod
    └── Dockerfile
```

---

## 四、架构图

```
┌──────────────────────────────────────────────────┐
│                  管理后台                          │
│              Vue 3 + Nuxt 3                       │
│            (接管原 admin-web)                      │
└─────────────────────┬────────────────────────────┘
                      │ HTTP (Hono)
┌─────────────────────▼────────────────────────────┐
│               调度服务（控制平面）                   │
│              TypeScript + Hono                     │
│         (取代原 orchestrator-go)                    │
│                                                   │
│  路由层 routes/    ───  HTTP API 接口               │
│  服务层 services/  ───  下游调用 + 会话存储          │
│  状态机 state/    ───  created→ready→active→closed │
│  类型层 types/    ───  contracts.ts（共享源）       │
└──┬────────┬────────┬────────┬────────────────────┘
   │ HTTP   │ HTTP   │ HTTP   │ HTTP
┌──▼────┐┌──▼────┐┌──▼────┐┌──▼──────────────┐
│ ASR   ││ TTS   ││Avatar ││ LLM             │
│Python ││Python ││Python ││Python           │
│FastAPI││FastAPI││FastAPI││FastAPI          │
│       ││       ││       ││                 │
│SenseV ││CosyV  ││MuseT  ││Qwen + Ollama    │
│oice   ││oice 2 ││alk    ││(→ vLLM 生产)    │
└───────┘└───────┘└───────┘└─────────────────┘

独立服务（后装，Docker Compose 中已保留）：
  ┌──────────┐  ┌──────────┐
  │ LiveKit  │  │   SRS    │
  │ WebRTC   │  │ RTMP/HLS │
  └──────────┘  └──────────┘
```

---

## 五、语言分布

```
TypeScript（团队主业）：
  ├── 调度服务（Hono）
  ├── 管理后台（Vue 3 / Nuxt 3）
  └── 前后端共享类型定义（contracts.ts）

Python（AI 必需）：
  ├── ASR 服务
  ├── TTS 服务
  ├── Avatar 服务
  └── LLM 服务
```

---

## 六、调度服务详细设计

### 6.1 项目结构

```
services/orchestrator-ts/
├── package.json
├── tsconfig.json
├── Dockerfile
├── src/
│   ├── index.ts               # 入口，启动 HTTP 服务
│   ├── app.ts                 # Hono app 装配（中间件、路由挂载）
│   ├── config/
│   │   └── env.ts             # 环境变量解析
│   ├── routes/
│   │   ├── health.ts          # GET /healthz
│   │   ├── info.ts            # GET /v1/info
│   │   ├── sessions.ts        # POST/GET/PATCH /v1/sessions
│   │   └── services.ts        # GET /v1/services/health
│   ├── services/
│   │   ├── downstream.ts      # 下游服务注册 + 健康检查聚合
│   │   └── session-store.ts   # 会话持久化（接口抽象，开发期 SQLite）
│   ├── state/
│   │   └── state-machine.ts   # 会话状态机
│   ├── types/
│   │   └── contracts.ts       # 共享类型定义
│   └── middleware/
│       ├── cors.ts
│       ├── request-id.ts
│       └── error-handler.ts
└── drizzle/
    └── migrations/
```

### 6.2 技术选型

| 依赖 | 版本 | 用途 |
|------|------|------|
| hono | ^4 | HTTP 框架 |
| drizzle-orm | ^0.36 | 数据库 ORM |
| better-sqlite3 | ^11 | SQLite 驱动（开发期） |
| zod | ^3 | 请求校验 |
| typescript | ^5.6 | 类型系统 |

### 6.3 API 契约（统一信封）

所有接口遵循统一 JSON 响应格式，与当前 Go 版完全兼容：

```typescript
// 成功响应
{
  "request_id": "uuid",
  "session_id": "uuid",   // 可选
  "status": "ok",
  "data": { ... },
  "meta": {
    "at": "2026-06-20T...",
    "took_ms": 42
  }
}

// 错误响应
{
  "request_id": "uuid",
  "status": "error",
  "error": {
    "code": "SESSION_NOT_FOUND",
    "message": "会话不存在",
    "detail": null
  },
  "meta": {
    "at": "2026-06-20T...",
    "took_ms": 5
  }
}
```

### 6.4 API 清单

| 方法 | 路径 | 说明 | 状态 |
|------|------|------|------|
| GET | `/healthz` | 自检 | 已实现 |
| GET | `/v1/info` | 服务信息 + 下游地址 | 已实现 |
| GET | `/v1/services/health` | 聚合下游健康 | 已实现 |
| POST | `/v1/sessions` | 创建会话 | 已实现（stub） |
| GET | `/v1/sessions` | 会话列表 | 已实现 |
| GET | `/v1/sessions/:id` | 会话详情 | 已实现 |
| PATCH | `/v1/sessions/:id` | 状态流转 | 已实现 |

### 6.5 会话状态机

```
created ──→ ready ──→ active ──→ closed
   │                                ↑
   └────────────────────────────────┘（允许从任意状态关闭）
```

校验规则：
- `created → ready`：允许
- `ready → active`：允许
- `active → closed`：允许
- `* → closed`：允许（从任意状态关闭）
- 其它状态跳转：拒绝

---

## 七、管理后台详细设计

### 7.1 技术选型

| 依赖 | 版本 | 用途 |
|------|------|------|
| vue | ^3.5 | 前端框架 |
| nuxt | ^3.13 | 全栈框架（SSR/路由/约定式路由） |
| typescript | ^5.6 | 类型系统 |

### 7.2 页面规划

```
pages/
├── index.vue              # 仪表盘首页
├── sessions/
│   ├── index.vue          # 会话列表
│   └── [id].vue           # 会话详情（状态流转）
└── services/
    └── index.vue          # 服务健康监控面板
```

| 页面 | 路由 | 功能 |
|------|------|------|
| 仪表盘 | `/` | 活跃会话数、服务健康摘要、最近会话 |
| 会话管理 | `/sessions` | 列表 + 创建 + 状态流转 |
| 服务监控 | `/services` | 4 个 AI 服务 + LiveKit + SRS 健康面板 |

### 7.3 组件树

```
components/
├── layout/
│   ├── AppHeader.vue       # 顶部导航
│   └── AppSidebar.vue      # 侧边栏
├── dashboard/
│   ├── StatCard.vue        # 统计卡片
│   └── SessionChart.vue    # 会话趋势
├── sessions/
│   ├── SessionTable.vue    # 会话表格
│   └── StatusBadge.vue     # 状态标签
└── services/
    ├── ServiceCard.vue     # 服务健康卡片
    └── HealthIndicator.vue # 健康指示灯
```

### 7.4 与调度服务的类型共享

调度服务 `types/contracts.ts` 为单一源。管理后台通过以下方式引用：

- **方案（推荐）**：Nuxt 层通过 `server/api/` 代理调度服务，前后端类型在 monorepo 共享包中定义
- **备选**：管理后台直接复制 `contracts.ts`，Git hook 检查同步

---

## 八、数据库设计

### 8.1 开发期：SQLite

```sql
-- 会话表
CREATE TABLE sessions (
    id          TEXT PRIMARY KEY,            -- UUID v7
    status      TEXT NOT NULL DEFAULT 'created',
    title       TEXT NOT NULL DEFAULT '',
    metadata    TEXT NOT NULL DEFAULT '{}',  -- JSON
    created_at  TEXT NOT NULL,              -- ISO 8601
    updated_at  TEXT NOT NULL,
    closed_at   TEXT                         -- nullable
);

-- 服务健康日志
CREATE TABLE service_health_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    service     TEXT NOT NULL,
    healthy     INTEGER NOT NULL,
    latency_ms  INTEGER,
    checked_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### 8.2 生产期迁移路径

SQLite → PostgreSQL 只需：
1. 切换 Drizzle 驱动（`better-sqlite3` → `pg`）
2. 运行 `drizzle-kit push` 生成 PG 兼容 DDL

---

## 九、渐进路线

### Phase 1：基础重写（核心链路）

- [ ] 创建 `services/orchestrator-ts`，用 Hono 重写调度服务
- [ ] 接入 SQLite，实现会话持久化
- [ ] API 契约与当前 Go 版完全兼容
- [ ] Docker Compose 中替换 `orchestrator-go` → `orchestrator-ts`
- [ ] 创建 `services/admin-web`（Nuxt 3 项目），实现三个页面
- [ ] 前后端类型通过 `contracts.ts` 共享

### Phase 2：LLM 接入（首条 AI 链路）

- [ ] 开发环境部署 Ollama，拉取 Qwen 模型
- [ ] `model-llm-python` 从 stub 改为真实调用 Ollama
- [ ] 管理后台增加对话测试页面

### Phase 3：全模型接入

- [ ] ASR：接入 SenseVoice
- [ ] TTS：接入 CosyVoice 2
- [ ] Avatar：接入 MuseTalk

### Phase 4：实时交互

- [ ] LiveKit room 创建与管理
- [ ] WebRTC 音视频流接入
- [ ] 管理后台集成 LiveKit SDK

### Phase 5：产品化

- [ ] SQLite → PostgreSQL 迁移
- [ ] 用户认证与权限
- [ ] 日志/监控/告警
- [ ] Kubernetes 部署

---

## 十、风险与缓解

| 风险 | 缓解 |
|------|------|
| Go 重写期间出现 API 不兼容 | Hono 版本逐接口对齐，现有 Go 版对照测试 |
| Python AI 模型接入难度高于预期 | 先用 Ollama 降低门槛，模型调用封装为独立 Python 包 |
| LiveKit 集成延迟主链路 | LiveKit 在 Phase 4 才启用，不影响前期 AI 对话链路 |
| SQLite → PG 迁移数据丢失 | Drizzle 同 ORM 切换，迁移脚本验证后再上线 |

---

## 十一、与原有设计的兼容性

- Docker Compose：替换 2 个服务名，其余 7 个不变
- API 契约：统一信封与 Go 版一致，下游 AI 服务无需改动
- 环境变量：`start.ps1` / `.env.example` 中变量名兼容
- 端口：沿用 5xxxx 范围
