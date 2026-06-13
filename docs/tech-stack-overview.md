# AvaStack 技术栈概览与学习资源索引

> 本文档是项目技术全景的快速参考，配合 [learning-roadmap.md](learning-roadmap.md) 实操路线图使用。路线图告诉你"怎么一步步学"，本文档提供各技术点的资源汇总。

---

## 项目技术全景

```text
┌──────────────────────────────────────────────────┐
│                   AvaStack 技术全景                │
├────────────┬──────────────┬───────────────────────┤
│  前端      │  后端编排     │  AI 模型服务          │
│  TypeScript│  Go 1.22     │  Python 3.11          │
│  Vite      │  标准库      │  FastAPI              │
│  原生 DOM  │  HTTP/JSON   │  Uvicorn              │
├────────────┴──────────────┴───────────────────────┤
│  基础设施: Docker Compose / LiveKit / SRS         │
│  AI 引擎:   SenseVoice / CosyVoice / MuseTalk     │
└──────────────────────────────────────────────────┘
```

---

## 技术速查表

| 类别 | 技术 | 用在哪里 |
|------|------|----------|
| 编程语言 | Go 1.22 | 编排控制层（orchestrator） |
| 编程语言 | Python 3.11 | 四个 AI 模型服务（ASR/TTS/LLM/Avatar） |
| 编程语言 | TypeScript (ES2020) | 管理后台 |
| Python 框架 | FastAPI 0.115.0 + Uvicorn 0.30.6 | 所有 AI 服务的 Web API |
| Python 库 | Pydantic 2.9.2 | 数据校验与序列化 |
| Python 库 | httpx 0.27.2 | LLM 服务调用外部推理引擎 |
| Go 库 | 标准库（net/http, sync, crypto/rand） | 编排器，无第三方依赖 |
| 前端构建 | Vite 5.4.8 | 管理后台的构建与开发服务器 |
| 容器化 | Docker + Docker Compose | 本地开发环境编排 7 个服务 |
| 实时通信 | LiveKit (WebRTC) | 数字人实时音视频传输 |
| 流媒体 | SRS v6 (RTMP/HLS/WebRTC) | 流媒体分发 |
| LLM 推理 | vLLM（计划中） | 自托管大模型推理引擎 |
| 数据库 | 无（当前阶段用内存存储） | 编排器使用 map + RWMutex 管理会话 |

---

## 各服务详情

### 编排层 — `orchestrator-go`（Go）

- **语言：** Go 1.22
- **依赖：** 纯标准库（net/http, sync, crypto/rand, encoding/json），无第三方依赖
- **职责：** 对外控制面，会话管理，服务路由，健康聚合
- **端口：** 8080
- **关键文件：**
  - `cmd/api/main.go` — 入口
  - `internal/httpapi/router.go` — HTTP 路由
  - `internal/controlplane/` — 服务注册、会话存储、状态机

### 四个 Python 模型服务（Python）

所有服务共用相同的核心依赖：

| 包名 | 版本 | 用途 |
|------|------|------|
| FastAPI | 0.115.0 | 异步 Web 框架 |
| Uvicorn | 0.30.6 | ASGI 服务器 |
| Pydantic | 2.9.2 | 数据校验与序列化 |
| httpx | 0.27.2 | 异步 HTTP 客户端（仅 model-llm 使用） |

| 服务 | 端口 | 职责 |
|------|------|------|
| model-asr-python | 8101 | 语音识别服务边界 |
| model-tts-python | 8102 | 语音合成服务边界 |
| model-avatar-python | 8103 | 数字人渲染服务边界 |
| model-llm-python | 8104 | LLM 网关边界 |

### 管理后台 — `admin-web`（TypeScript）

- **语言：** TypeScript (ES2020)
- **构建工具：** Vite 5.4.8
- **特点：** 无 React/Vue 框架，原生 TS + fetch 操作 DOM
- **端口：** 4173

---

## 基础设施

| 组件 | 镜像 | 用途 |
|------|------|------|
| LiveKit | livekit/livekit-server | WebRTC 实时音视频传输，房间管理 |
| SRS | ossrs/srs:6 | RTMP/HLS/HTTP-FLV 流媒体分发 |
| vLLM | （计划中） | 自托管 LLM 推理引擎，OpenAI 兼容接口 |

---

## 数据库

当前阶段不使用任何数据库。编排器使用内存态 `SessionStore`（基于 `sync.RWMutex` + `map[string]Session`），后续 roadmap 阶段 5 计划引入持久化存储。

---

## 容器化

| 工具 | 用途 |
|------|------|
| Docker Compose | 本地开发编排 7 个服务 |
| Docker 多阶段构建 | 每个服务独立 Dockerfile |
| Rancher Desktop | Windows 推荐容器运行时（免费无限制） |

---

## 计划中的 AI 模型

| 层级 | 首选方案 | 替代方案 | 难度 |
|------|----------|----------|:--:|
| ASR（语音识别） | SenseVoice | FunASR, Whisper | ⭐⭐ |
| TTS（语音合成） | CosyVoice 2 | FishSpeech, EdgeTTS | ⭐⭐ |
| LLM（大语言模型） | Qwen + vLLM | TGI, Ollama | ⭐⭐⭐ |
| Avatar（数字人渲染） | MuseTalk | Wav2Lip | ⭐⭐⭐⭐ |

---

## 按服务分的学习顺序

由浅入深，推荐按以下顺序阅读代码：

```
难度 ⭐         难度 ⭐         难度 ⭐⭐        难度 ⭐⭐       难度 ⭐⭐⭐      难度 ⭐⭐⭐⭐
model-asr  →  model-tts  →  model-llm  →  admin-web  →  orchestrator  →  model-avatar
   接口清晰       结构相同      多了外部调用    前端调 API     所有服务的"大脑"   视频渲染，最后看
   代码量少       换个名字       httpx 客户端   原生 TS        Go + 并发 + 状态机
```

---

## 推荐学习工具

| 工具 | 用途 |
|------|------|
| VS Code | 写代码、看代码 |
| Thunder Client（VS Code 插件） | 测试 API 接口 |
| Docker Desktop / Rancher Desktop | 跑容器（Windows 推荐 Rancher Desktop） |
| ChatGPT / Claude | 让 AI 用通俗语言解释代码 |
| draw.io | 画架构图，帮助理清思路 |

---

## 技术学习资源索引

> 更详细的分步骤学习计划见 [learning-roadmap.md](learning-roadmap.md)。

### Python

| 主题 | 资源 |
|------|------|
| 基础语法 | [Python 官方教程（中文）](https://docs.python.org/zh-cn/3/tutorial/) 前 6 章 |
| 虚拟环境 | [venv 文档](https://docs.python.org/zh-cn/3/library/venv.html) |
| FastAPI | [FastAPI 官方教程（中文）](https://fastapi.tiangolo.com/zh/) |
| Pydantic | [Pydantic 文档](https://docs.pydantic.dev/latest/) |

### Go

| 主题 | 资源 |
|------|------|
| 基础语法 | [Go 之旅](https://go.dev/tour/) 前 10 节 |
| 并发模型 | [Go 并发](https://go.dev/tour/concurrency/1) |
| 标准库 HTTP | [net/http 文档](https://pkg.go.dev/net/http) |

### TypeScript / 前端

| 主题 | 资源 |
|------|------|
| TypeScript 基础 | [TS 手册](https://www.typescriptlang.org/docs/handbook/intro.html) |
| Vite | [Vite 指南（中文）](https://cn.vitejs.dev/guide/) |
| Fetch API | [MDN Fetch（中文）](https://developer.mozilla.org/zh-CN/docs/Web/API/Fetch_API) |

### Docker

| 主题 | 资源 |
|------|------|
| 入门概念 | [Docker Get Started](https://docs.docker.com/get-started/) |
| Compose | [Compose 快速入门](https://docs.docker.com/compose/gettingstarted/) |

### 实时通信 / LiveKit

| 主题 | 资源 |
|------|------|
| WebRTC 基础 | [WebRTC 概述](https://webrtc.org/getting-started/overview) |
| LiveKit 概念 | [LiveKit 文档](https://docs.livekit.io/home/) Concepts 部分 |

---

> **下一步：** 打开 [learning-roadmap.md](learning-roadmap.md) 开始按实操路线学习。
