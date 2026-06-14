# AvaStack 技术学习路线图

> 面向零基础或转行同学的实操型学习路线。目标不是让你一下子学完所有技术，而是让你能把项目跑起来、看懂骨架、改动小功能，并逐步具备继续推进这个仓库的能力。

---

## 先说结论：按这份路线能学到什么

如果你是小白，按这份路线走，**可以做到**：

- 把 AvaStack 当前骨架项目跑起来
- 看懂每个服务分别负责什么
- 理解一次请求是怎么在前端、编排层、模型服务之间流动的
- 改一些小功能，例如：
  - 增加或修改一个接口字段
  - 调整会话状态展示
  - 修改 stub 服务返回的数据
  - 给管理后台增加简单展示

但你要知道，**当前仓库本身还不是完整产品**。它现在更像一个“长期演进的服务化骨架”，还没有接入完整的真实模型链路。因此按这份路线学完后，你更接近的是：

- 能接手当前仓库继续开发
- 能理解后续应该怎么把 stub 替换成真实能力

而不是：

- 一个人马上把数字人完整产品全部做完

---

## 这份路线图的使用方式

请不要把它当成“从头到尾背完”的教材，而要把它当成一个**边跑项目边学**的路线图。

建议你严格按这个顺序来：

1. 先把项目跑起来，建立整体感觉
2. 再理解架构和接口，不要一上来就啃底层原理
3. 然后按服务读代码，先容易后困难
4. 最后再进入 Go、实时音视频、真实模型替换这些进阶主题

---

## 项目技术全景

先别急着学语法，先知道你面对的是什么：

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

### 技术速查表

| 类别 | 技术 | 当前用在哪里 |
|------|------|--------------|
| 编程语言 | Python 3.11 | 四个模型服务的骨架 |
| 编程语言 | Go 1.22 | 编排层 `orchestrator-go` |
| 编程语言 | TypeScript | 管理后台 `admin-web` |
| Python 框架 | FastAPI + Uvicorn | 模型服务 HTTP API |
| Go 能力 | `net/http` 标准库 | 编排层路由和控制面接口 |
| 前端工具 | Vite | 管理后台开发与构建 |
| 容器化 | Docker Compose | 本地拉起整套服务 |
| 实时通信 | LiveKit | 后续实时音视频链路 |
| 流媒体 | SRS | 后续分发和桥接能力 |
| 推理后端 | vLLM（计划中） | 后续 LLM 真实化 |

### 学习方式先定好

这份路线图后面会给你很多“学什么”。但更重要的是，**怎么学**。

不要这样学：

- 一次打开十几个教程标签页
- 从头到尾把一门语言完整刷完
- 看了半天教程，却没有立刻回仓库验证

建议你只用这个节奏：

1. 只看一个技术的一个很小主题
2. 最多看 20 到 40 分钟
3. 立刻回到仓库找对应代码
4. 做一个很小的改动或验证

后面我给每个技术配的资源，也都按这个思路来，不会只给你一堆泛泛的链接。

---

## 第 0 阶段：先把项目跑起来（最重要）

> 目标：先看到项目“活着”，建立整体认识。

很多小白卡住，不是因为不会写代码，而是因为一开始就扎进语法里，结果一直不知道项目整体在做什么。这个项目最正确的起点，不是先学 Python，也不是先学 Go，而是先把它跑起来。

### 你要做什么

1. 阅读 [README.md](/E:/GitHub/AvaStack/README.md:36)
2. 理解推荐启动方式是 `./start.ps1`
3. 知道项目是通过 `compose.yaml` 拉起多个服务
4. 启动后访问几个关键地址

### 你至少要知道这几个入口

- 管理台：`http://localhost:54173`
- 编排层信息：`http://localhost:58080/v1/info`
- 服务健康：`http://localhost:58080/v1/services/health`
- 会话列表：`http://localhost:58080/v1/sessions`
- 编排层健康：`http://localhost:58080/healthz`

### 推荐实践任务

先运行：

```powershell
./start.ps1
```

启动成功后，再执行一次会话创建请求：

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:58080/v1/sessions -ContentType "application/json" -Body '{"mode":"text_chat","avatar_id":"default-avatar","user_id":"demo-user"}'
```

然后刷新管理台页面，看看会话列表是否发生变化。

### 这一阶段的完成标准

满足下面 4 条，就算过关：

- 你知道这个仓库不是单体应用，而是一组服务骨架
- 你能说出 `start.ps1` 的作用是帮助启动本地开发环境
- 你能访问至少一个健康检查接口和一个业务接口
- 你能创建一个会话，并在页面或接口响应里看到结果

### 如果这一阶段卡住怎么办

优先排查这几件事：

- 容器运行时是否正常
- `./start.ps1` 是否已经完成启动
- `compose.yaml` 中的服务是否都成功拉起
- 端口是否被占用

如果你连这一步都没跑通，先不要继续学下面的内容。

### 第 0 阶段最小学习处方

这一阶段不要学 Docker 全家桶，只学“够把项目跑起来”的部分。

#### 先看哪里

1. [README.md](/E:/GitHub/AvaStack/README.md:36)
2. [Docker Get started](https://docs.docker.com/get-started/)
3. [Docker Compose Quickstart](https://docs.docker.com/compose/gettingstarted/)

#### 只看什么

- Docker 里只先理解：
  - 什么是镜像
  - 什么是容器
  - 什么是端口映射
- Compose 里只先理解：
  - 一个 `compose.yaml` 可以启动多个服务
  - 每个服务有自己的镜像、端口、环境变量

#### 看完立刻做什么

1. 打开 [compose.yaml](/E:/GitHub/AvaStack/compose.yaml:1)
2. 不用逐行看，只回答这 3 个问题：
   - 这里一共起了哪些服务？
   - 哪个服务暴露了 `8080`？
   - 哪个服务对应管理台？
3. 然后运行 `./start.ps1`

#### 这一阶段不要做什么

- 不要现在去学怎么写 Dockerfile
- 不要现在去背 Compose 全部字段
- 不要现在碰 Kubernetes

---

## 第 1 阶段：看懂架构和服务边界

> 目标：知道“谁负责什么”，而不是只盯着某一个文件。

### 先读这 3 份文档

1. [architecture.md](/E:/GitHub/AvaStack/docs/architecture.md:1)
2. [service-decomposition.md](/E:/GitHub/AvaStack/docs/service-decomposition.md:1)
3. [shared/contracts/README.md](/E:/GitHub/AvaStack/shared/contracts/README.md:1)

### 这一阶段你要搞懂的问题

- 为什么这个项目要拆成多个服务
- 为什么模型服务用 Python，编排层用 Go，后台用 TypeScript
- 什么是“共享契约”
- 什么是 `session_id`
- 为什么现在先用 stub，而不是一开始就接真实模型

### 重点理解的服务职责

| 服务 | 作用 |
|------|------|
| `services/orchestrator-go` | 对外控制面，负责会话、路由、聚合 |
| `services/model-asr-python` | 语音识别服务边界 |
| `services/model-tts-python` | 语音合成服务边界 |
| `services/model-llm-python` | LLM 网关边界 |
| `services/model-avatar-python` | 数字人渲染服务边界 |
| `services/admin-web` | 管理后台与运维入口 |
| `infra/livekit` | 实时音视频基础设施配置 |
| `infra/srs` | 流媒体分发配置 |

### 推荐实践任务

看完文档后，用自己的话回答这两个问题：

1. 如果以后把 `model-llm-python` 的后端从 stub 换成 vLLM，为什么不需要重写整个项目？
2. 为什么 `orchestrator-go` 不直接把 ASR、TTS、LLM、Avatar 的逻辑全部写进去？

### 这一阶段的完成标准

- 你能画出“前端 -> 编排层 -> 模型服务”的大致关系
- 你知道仓库当前的重点是“固定服务边界和契约”
- 你明白现在的项目骨架是为了后续替换真实模型做准备

---

## 第 2 阶段：先学最容易上手的 Python 服务

> 目标：先能看懂一个最简单的服务长什么样。

### 为什么先学 Python

因为这几个模型服务结构最简单、代码量最小，而且 Python 对小白最友好。你不需要一开始就理解并发、状态机、路由聚合这些更复杂的内容。

### 先看哪个服务

建议按这个顺序：

1. `model-asr-python`
2. `model-tts-python`
3. `model-llm-python`
4. `model-avatar-python`

原因很简单：

- `asr` 和 `tts` 更像标准示例
- `llm` 多了一层“网关”的概念
- `avatar` 在业务上最抽象，先别急着看它

### Python 只需要先学到什么程度

| 学什么 | 学到什么程度 |
|--------|-------------|
| 变量、函数、字典、列表 | 能看懂简单函数和返回值 |
| 虚拟环境 | 知道 `venv` 是隔离依赖的 |
| `pip install` | 会安装依赖即可 |
| 类和数据模型 | 看懂 Pydantic 模型字段 |
| `def` 和 `return` | 能读懂接口处理函数 |

### FastAPI 需要理解的核心点

- `@app.get("/healthz")` 表示一个 GET 接口
- `@app.post(...)` 表示一个 POST 接口
- `BaseModel` 用来定义请求数据结构
- 返回的 Python 字典会自动变成 JSON

### 推荐阅读文件

- [model-asr-python/app/main.py](/E:/GitHub/AvaStack/services/model-asr-python/app/main.py:1)
- [model-tts-python/app/main.py](/E:/GitHub/AvaStack/services/model-tts-python/app/main.py:1)
- [model-llm-python/app/main.py](/E:/GitHub/AvaStack/services/model-llm-python/app/main.py:1)
- [model-avatar-python/app/main.py](/E:/GitHub/AvaStack/services/model-avatar-python/app/main.py:1)

### 推荐实践任务

先完成这两个最小练习：

1. 找到每个服务里的 `/healthz` 接口
2. 找到 `model-llm-python` 里的 `POST /v1/chat` 接口，理解它如何接收 `session_id` 和 `message`

注意：当前仓库里 **不是** `/v1/chat/completions`，而是 `POST /v1/chat`。

### 第 2 阶段最小学习处方

这一阶段不要想着“学完 Python 再看项目”，而是反过来：为了看懂项目，只补最少的 Python。

#### 第一天只做这一轮

1. 看 [Python 官方教程（中文）](https://docs.python.org/zh-cn/3/tutorial/)
   只看：
   - 变量
   - `if`
   - 函数
   - 列表和字典
2. 回到 [model-asr-python/app/main.py](/E:/GitHub/AvaStack/services/model-asr-python/app/main.py:1)
3. 只找 3 个东西：
   - `app = FastAPI(...)`
   - `@app.get("/healthz")`
   - `return {...}`

#### 第二天只做这一轮

1. 看 [FastAPI 官方教程（中文）](https://fastapi.tiangolo.com/zh/)
   只看：
   - First Steps
   - Path Operation
   - Request Body
2. 回到 [model-llm-python/app/main.py](/E:/GitHub/AvaStack/services/model-llm-python/app/main.py:1)
3. 只找 3 个东西：
   - `class ChatRequest(BaseModel)`
   - `@app.post("/v1/chat")`
   - `payload.message` 是怎么被用到的

#### 第三天只做这一轮

1. 如果你还不理解 `BaseModel`，再看 [Pydantic Get Started](https://pydantic.dev/docs/validation/latest/get-started/)
2. 然后把 `stub response` 改成你自己的文本
3. 重启服务后验证返回是否变化

#### 这阶段的核心不是“学会 Python”

而是做到：

- 看懂一个接口函数
- 看懂一个请求模型
- 敢改一个返回值并验证

### 进阶一点的小练习

把某个模型服务返回的 `"stub response"` 改成你自己的文本，再重启服务，看接口返回有没有变化。

### 这一阶段的完成标准

- 你能看懂一个 FastAPI 服务的基本结构
- 你知道 Pydantic 模型是用来约束请求字段的
- 你能独立找到某个接口的输入和输出
- 你能改动一个 stub 返回值并验证成功

---

## 第 3 阶段：理解共享契约和会话模型

> 目标：知道接口不是随便返回的，而是有统一约定。

小白很容易只盯着“这个函数返回了什么”，但在服务化项目里，更重要的是：**为什么所有服务都要遵守同一套结构**。

### 必看内容

重点看 [shared/contracts/README.md](/E:/GitHub/AvaStack/shared/contracts/README.md:11) 里的这些部分：

- 通用响应包裹
- 错误响应约定
- Session Schema
- 会话创建请求
- 会话列表响应
- 会话更新请求

### 你要重点记住的字段

- `request_id`
- `session_id`
- `status`
- `data`
- `meta`

### 为什么这一阶段重要

以后你不管是改 Go 编排层、改 Python 服务，还是改前端展示，都离不开这套契约。如果你先把契约看懂，后面很多代码会突然变得清晰。

### 推荐实践任务

做一件非常有价值的小事：

1. 创建一个会话
2. 调 `GET /v1/sessions`
3. 对照契约文档，看返回结构里的字段是不是能一一对应上

### 这一阶段的完成标准

- 你知道为什么每个服务不应该各自返回一套乱七八糟的 JSON
- 你能解释 `session_id` 在控制面里的含义
- 你能看懂一个标准响应的外层结构

---

## 第 4 阶段：进入 Go 编排层

> 目标：看懂项目的“大脑”现在在做什么。

### 这一阶段不要一上来学全部 Go

你不需要先把 Go 学完整，再来读这个项目。对当前仓库来说，只要先理解这些就够了：

| 学什么 | 学到什么程度 |
|--------|-------------|
| `struct` | 看懂数据结构 |
| `func` | 看懂函数定义 |
| `map` | 看懂内存态数据存储 |
| `net/http` | 看懂 HTTP 路由处理 |
| 指针 | 知道 `*Router` 代表什么 |

### 推荐阅读顺序

1. [cmd/api/main.go](/E:/GitHub/AvaStack/services/orchestrator-go/cmd/api/main.go:1)
2. [internal/httpapi/router.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/httpapi/router.go:1)
3. [internal/controlplane/types.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/controlplane/types.go:1)
4. [internal/controlplane/store.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/controlplane/store.go:1)
5. [internal/controlplane/services.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/controlplane/services.go:1)
6. [internal/controlplane/status.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/controlplane/status.go:1)

### 你要优先看懂哪些接口

在 [router.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/httpapi/router.go:34) 里先看这些：

- `GET /healthz`
- `GET /v1/info`
- `GET /v1/services/health`
- `POST /v1/sessions`
- `GET /v1/sessions`
- `GET /v1/sessions/{session_id}`
- `PATCH /v1/sessions/{session_id}`

### 当前编排层到底在干什么

现阶段它主要做的是：

- 维护最小控制面接口
- 管理内存态会话
- 聚合下游服务健康状态
- 固定对前端和下游的接口结构

它**还没有**真正承担完整的实时音视频调度和真实模型编排，所以你不要用“完整产品大脑”的预期去看它。

### 推荐实践任务

完成以下任意一个，就说明你真的开始会读 Go 代码了：

- 画出 `POST /v1/sessions` 的处理流程
- 说清楚 `SessionStore` 是怎么创建、查询、更新会话的
- 找到会话状态校验逻辑在哪里

### 这一阶段的完成标准

- 你能跟着路由找到对应处理函数
- 你能解释当前会话数据为什么是内存态存储
- 你能看懂“接口层 -> 控制层 -> 存储层”的基本分工

---

## 第 5 阶段：理解管理后台前端

> 目标：知道前端现在不是重点难点，但它是最容易做出可见改动的地方。

### 这个前端有什么特点

这个仓库里的前端很适合小白入门，因为它：

- 没有 React
- 没有 Vue
- 没有复杂状态管理
- 就是原生 TypeScript + DOM + `fetch`

这意味着你很容易从“看懂”走到“自己改动”。

### 先学什么

| 学什么 | 学到什么程度 |
|--------|-------------|
| TypeScript 基础 | 看懂类型定义 |
| `fetch()` | 看懂如何调用后端接口 |
| DOM 操作 | 看懂字符串模板如何渲染页面 |
| Vite | 知道它是开发服务器和构建工具 |

### 推荐阅读文件

- [admin-web/src/main.ts](/E:/GitHub/AvaStack/services/admin-web/src/main.ts:1)
- [admin-web/src/styles.css](/E:/GitHub/AvaStack/services/admin-web/src/styles.css:1)

### 你要优先看懂什么

在 [main.ts](/E:/GitHub/AvaStack/services/admin-web/src/main.ts:36) 里重点看：

- `fetchJSON()` 怎么请求接口
- `renderHealth()` 怎么显示服务健康
- `renderSessions()` 怎么显示会话列表
- `bootstrap()` 怎么在页面初始化时拉数据

### 推荐实践任务

做一个很合适的小白练习：

- 在会话列表里多展示一个字段
- 或者给服务健康状态加一个更醒目的文案
- 或者把“当前还没有会话”这句提示改成你自己的版本

### 第 5 阶段最小学习处方

前端这块你不用先学框架，先把这个项目的原生 TS 页面看懂。

#### 第一天只做这一轮

1. 看 [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
   只看：
   - `type`
   - 对象类型
   - 函数
2. 回到 [admin-web/src/main.ts](/E:/GitHub/AvaStack/services/admin-web/src/main.ts:13)
3. 只找：
   - `type ServiceHealth`
   - `type SessionItem`
   - `fetchJSON()`

#### 第二天只做这一轮

1. 看 [MDN Fetch API（中文）](https://developer.mozilla.org/zh-CN/docs/Web/API/Fetch_API)
2. 回到 [admin-web/src/main.ts](/E:/GitHub/AvaStack/services/admin-web/src/main.ts:99)
3. 只看 `bootstrap()`，回答这两个问题：
   - 它先请求了哪个接口？
   - 请求失败时页面会怎么显示？

#### 第三天只做这一轮

1. 如果你对 DOM 完全陌生，再补 [MDN JavaScript 学习路径（中文）](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Core/Scripting)
2. 回来看 `renderHealth()` 和 `renderSessions()`
3. 把“当前还没有会话”改成你自己的话

#### 这阶段的核心不是“学会前端”

而是做到：

- 看懂页面怎么拿数据
- 看懂页面怎么显示数据
- 自己能改一个展示细节

### 这一阶段的完成标准

- 你知道前端是怎么从编排层拿数据的
- 你能找到接口返回值最终显示到页面的代码位置
- 你能完成一次简单的页面文案或字段展示修改

---

## 第 6 阶段：再回头系统学习语言基础

> 目标：在已经看过真实项目后，再补语言基础，效率会高很多。

这时候你再系统补语言，会比一开始直接看教程轻松很多，因为你已经知道这些语言在项目里各自干什么。

### 建议学习顺序

1. Python
2. TypeScript
3. Go

### 为什么 Go 放后面

不是因为 Go 不重要，而是因为对于这个项目的小白上手路径来说：

- Python 服务更短、更直观
- TypeScript 前端改动更容易看到结果
- Go 编排层涉及接口设计、状态流转、存储和聚合，对新手更抽象

### 这一阶段的核心原则

语言学习不要追求“一口气学全”，而要按下面的标准来：

- 先学“看得懂当前项目代码”需要的最小知识
- 再学“能改一个小功能”需要的知识
- 最后再补“更系统、更完整”的语言能力

也就是说，你现在的目标不是成为某门语言专家，而是先做到：

- 能读
- 能改
- 能验证

---

## 语言学习细化版

下面这部分是给小白单独准备的“语言补课清单”。如果你担心自己语言基础太弱，可以直接照着这部分补。

### Python：第一优先级

> 目标：能看懂 4 个模型服务，能改简单接口返回。

#### 为什么先学 Python

因为 AvaStack 里最容易看懂的服务基本都在 Python 这一侧，而且语法相对更接近自然语言。

#### 第一轮先学什么

先只学下面这些，足够你读当前仓库：

| 主题 | 要学到什么程度 | 在仓库里对应哪里 |
|------|----------------|------------------|
| 变量 | 知道字符串、数字、布尔值是什么 | 各服务返回的 JSON 字段 |
| 列表和字典 | 看懂 `[]` 和 `{}` | 接口返回体 |
| 函数 | 看懂 `def xxx():` | 所有接口函数 |
| 条件判断 | 看懂 `if` | 简单逻辑分支 |
| 类 | 知道类是“数据模板” | Pydantic 请求模型 |
| 导入 | 看懂 `import` 和 `from ... import ...` | 文件开头 |
| 返回值 | 看懂 `return {...}` | 所有接口返回 |

#### 第二轮再补什么

当你已经能大致看懂代码后，再补：

| 主题 | 要学到什么程度 | 为什么要学 |
|------|----------------|-----------|
| 虚拟环境 `venv` | 会创建和激活即可 | 隔离 Python 依赖 |
| `pip` | 会安装依赖即可 | 跑服务时会用到 |
| JSON | 知道 JSON 和 Python 字典的关系 | 理解 HTTP API |
| 类型注解 | 认识 `str`、`dict`、`list` | 看请求模型更轻松 |
| 异步 `async/await` | 先知道概念，不要求精通 | FastAPI 常见概念 |

#### 在这个项目里，Python 你应该先读哪几个点

建议按这个顺序：

1. `app = FastAPI(...)`
2. `@app.get("/healthz")`
3. `@app.post(...)`
4. `class XxxRequest(BaseModel)`
5. `return {...}`

#### Python 小练习

先做这 3 个就够：

1. 找到 `model-asr-python` 里的 `/healthz`
2. 找到 `model-llm-python` 里的 `ChatRequest`
3. 把某个 stub 返回文本改掉并验证

#### Python 资料怎么用到项目里

不是“看完教程再回来”，而是：

1. 看 Python 基础
2. 回来找 `def`
3. 看 FastAPI 路由
4. 回来找 `@app.get` / `@app.post`
5. 看 Pydantic
6. 回来找 `BaseModel`

你每看一个概念，都必须在项目里找到它一次，不然很容易又变成“看了但不会用”。

#### Python 学到什么程度算过关

- 你能看懂 FastAPI 服务的基本结构
- 你能解释 `BaseModel` 是用来约束请求字段的
- 你能自己改一个接口返回值

---

### TypeScript：第二优先级

> 目标：能看懂管理后台页面怎么请求接口、怎么把数据渲染出来。

#### 为什么第二个学 TypeScript

因为前端改动反馈最直观。你改完页面，刷新浏览器就能看到效果，这对小白建立信心非常有帮助。

#### 第一轮先学什么

| 主题 | 要学到什么程度 | 在仓库里对应哪里 |
|------|----------------|------------------|
| 变量和函数 | 看懂 `const`、`function` | `main.ts` |
| 对象和数组 | 看懂接口返回数据结构 | 健康检查和会话列表 |
| 类型定义 | 看懂 `type Xxx = {}` | `ServiceHealth`、`SessionItem` |
| 字符串模板 | 看懂 `` `...${x}...` `` | 页面渲染 |
| `async/await` | 看懂异步请求流程 | `fetchJSON()`、`bootstrap()` |
| DOM 查询 | 看懂 `document.querySelector` | 页面元素操作 |

#### 第二轮再补什么

| 主题 | 要学到什么程度 | 为什么要学 |
|------|----------------|-----------|
| `fetch()` | 会发 GET 请求，理解返回 JSON | 调后端接口 |
| 错误处理 | 看懂 `try/catch` | 请求失败时页面提示 |
| 模块导入 | 看懂 `import "./styles.css"` | 前端入口文件结构 |
| Vite | 知道它是开发服务器 | 前端本地运行与打包 |

#### 在这个项目里，TypeScript 先看什么

建议按这个顺序：

1. `ORCHESTRATOR_BASE_URL`
2. `fetchJSON()`
3. `renderHealth()`
4. `renderSessions()`
5. `bootstrap()`

#### TypeScript 小练习

先做这 3 个：

1. 把“当前还没有会话”改成你自己的提示语
2. 给会话列表增加一个字段展示
3. 让服务健康状态显示更明显一点

#### TypeScript 资料怎么用到项目里

建议你一直围绕这 3 个问题学：

1. 这个类型定义在约束什么数据？
2. 这个 `fetch` 请求的是哪个接口？
3. 这段字符串模板最终会显示到页面哪里？

如果你一边看教程，一边能回答这 3 个问题，学习就不会发散。

#### TypeScript 学到什么程度算过关

- 你能看懂页面是怎么请求后端的
- 你能找到数据是怎么渲染到页面上的
- 你能完成一次简单页面改动

---

### Go：第三优先级

> 目标：能看懂编排层的路由、会话存储和健康聚合逻辑。

#### 为什么 Go 放第三个

因为 Go 在这个项目里承担的是编排层职责，虽然代码并不算特别复杂，但概念上比 Python 模型服务和前端展示更抽象。

#### 第一轮先学什么

| 主题 | 要学到什么程度 | 在仓库里对应哪里 |
|------|----------------|------------------|
| `package` 和 `import` | 看懂文件归属和依赖 | 每个 Go 文件开头 |
| `func` | 看懂函数定义 | 路由处理函数 |
| `struct` | 看懂结构体字段 | Session 相关类型 |
| `map` | 看懂键值存储 | 内存态会话表 |
| 切片 `[]T` | 看懂列表返回 | 会话列表 |
| 指针 `*Type` | 知道“指向某个对象”即可 | `*Router`、`*SessionStore` |
| `if` 和错误处理 | 看懂 `if err != nil` | JSON 解码、请求校验 |

#### 第二轮再补什么

| 主题 | 要学到什么程度 | 为什么要学 |
|------|----------------|-----------|
| `net/http` | 理解 HTTP 处理函数签名 | 看懂路由 |
| JSON 编解码 | 看懂 `json.NewDecoder`、`json.NewEncoder` | 请求和响应 |
| 方法接收者 | 看懂 `func (r *Router) ...` | 理解路由组织方式 |
| 时间处理 | 看懂 `time.Now()` | 会话时间字段 |
| 并发基础 | 先知道 goroutine/channel 是什么 | 后续再深入，不必先精通 |

#### 在这个项目里，Go 先看什么

建议按这个顺序：

1. 路由注册
2. `writeJSON()`
3. `createSession()`
4. `listSessions()`
5. `updateSessionByID()`
6. `SessionStore`
7. 服务健康聚合

#### Go 小练习

先做这 3 个：

1. 找出 `POST /v1/sessions` 对应哪个函数
2. 找出会话列表是从哪里读出来的
3. 找出状态更新失败时为什么会返回 `bad_request`

#### Go 资料怎么用到项目里

不要先去系统学一大堆 Go 语法。更实用的顺序是：

1. 看 [Tutorial: Get started with Go](https://go.dev/doc/tutorial/getting-started)
2. 立刻回来看 [router.go](/E:/GitHub/AvaStack/services/orchestrator-go/internal/httpapi/router.go:1)
3. 不会的语法再去看 [A Tour of Go](https://go.dev/tour/)
4. 遇到写法习惯问题，再查 [Effective Go](https://go.dev/doc/effective_go)

你可以把 Go 当成“为了解这条请求链路才学”，而不是“先学会 Go 才能看懂项目”。

#### Go 学到什么程度算过关

- 你能从接口路径追到处理函数
- 你能解释 `SessionStore` 干了什么
- 你能看懂一个简单的请求处理流程

---

## 建议的语言学习节奏

如果你完全没有编程基础，可以按这个节奏来：

### 第 1 周

- 先跑项目
- 同时补一点 Python 最基础语法
- 看 `model-asr-python` 和 `model-tts-python`

### 第 2 周

- 继续补 Python 和 FastAPI
- 开始读 `model-llm-python`
- 练习改 stub 返回值

### 第 3 周

- 开始补 TypeScript 基础
- 看 `admin-web/src/main.ts`
- 练习改页面文案和字段展示

### 第 4 周

- 开始补 Go 最基础语法
- 读 `router.go` 和 `store.go`
- 追踪 `POST /v1/sessions` 的调用路径

### 第 5 周以后

- 继续查漏补缺
- 哪块最常碰，就优先补哪块
- 不要急着进入 LiveKit、SRS、vLLM 这些更重的主题

---

## 给完全零基础同学的现实建议

如果你现在三门语言都不会，不要给自己定“本周全学会”的目标。更现实的目标应该是：

- 今天先把项目跑起来
- 明天先看懂一个 Python 接口
- 后天先改一行返回值
- 再后面开始看前端和 Go

你不是要先学会语言再碰项目，而是要**借着项目去学语言**。对这个仓库来说，这条路反而更适合小白。

---

## 第 7 阶段：最后再碰 LiveKit、SRS 和真实模型

> 目标：把“基础骨架理解”升级到“知道未来怎么演进”。

### 为什么放最后

因为这些内容更偏进阶：

- LiveKit 涉及实时音视频
- SRS 涉及流媒体分发
- vLLM 涉及推理后端
- SenseVoice / CosyVoice / MuseTalk 涉及真实模型接入

而当前仓库阶段，重点仍然是服务边界和控制面骨架，不是完整的实时能力。

### 这一阶段你只需要先理解什么

- `infra/livekit/livekit.yaml` 是 LiveKit 的基础配置
- `infra/srs/srs.conf` 是 SRS 的基础配置
- `infra/vllm/README.md` 说明未来 LLM 真实化的方向

### 第 7 阶段去哪里学

| 技术 | 推荐地址 | 当前先学到什么程度 |
|------|----------|-------------------|
| WebRTC | [WebRTC Overview](https://webrtc.org/getting-started/overview) | 先知道房间、音视频流、实时传输这些概念 |
| LiveKit | [LiveKit Documentation](https://docs.livekit.io/intro/overview/) | 先理解它是本项目的 RTC 基础设施 |
| SRS | [SRS 官方文档（中文）](https://ossrs.io/lts/zh-cn/docs/v6/doc/introduction) | 先知道它负责流媒体分发和桥接 |
| vLLM | [vLLM 文档](https://docs.vllm.ai/en/latest/) | 先知道它是未来 LLM 推理后端 |

### 这一阶段怎么学才不容易劝退

这一阶段不要上来就啃所有细节。更好的方法是：

1. 先看概念页
2. 只回答“它在 AvaStack 里负责什么”
3. 暂时不要深入到部署参数、协议细节和性能调优

你先知道它们在系统中的位置，比先精通它们更重要。

### 对小白最重要的认知

你现在不需要会调 WebRTC，不需要会调 GPU，不需要会部署真实模型，先知道这些能力未来会接进来，并且仓库已经为它们预留了位置，就够了。

---

## 推荐的代码阅读顺序

如果你喜欢“对着代码学”，建议按下面顺序读：

```text
第 1 批：最容易
services/model-asr-python/app/main.py
services/model-tts-python/app/main.py

第 2 批：稍微复杂一点
services/model-llm-python/app/main.py
services/admin-web/src/main.ts

第 3 批：开始进入核心
services/orchestrator-go/internal/httpapi/router.go
services/orchestrator-go/internal/controlplane/store.go
services/orchestrator-go/internal/controlplane/types.go

第 4 批：最后看进阶能力
infra/livekit/livekit.yaml
infra/srs/srs.conf
docs/architecture.md
```

---

## 推荐你做的 5 个小练习

如果你把下面 5 个小练习都做完，说明你已经不只是“看懂”，而是开始能真正接手这个项目了。

1. 把项目跑起来，并访问所有关键接口
2. 创建一个会话，并在管理台看到它
3. 修改一个模型服务的 stub 返回值并验证
4. 给前端会话列表增加一个展示字段
5. 追踪一次 `POST /v1/sessions` 从请求到返回的代码路径

---

## 学到什么程度，才算“能接手当前项目”

满足下面这些，就可以说你已经能接手当前仓库的骨架开发：

- 你能独立启动项目
- 你能解释仓库的分层结构
- 你能看懂至少一个 Python 服务和一个 Go 接口
- 你能修改前端一个小展示功能
- 你能修改一个接口返回结构并同步验证
- 你知道当前仓库还是 stub 骨架，不会误以为它已经是完整产品

---

## 给小白的最后几个建议

### 1. 不要想着一次学会全部技术

这个项目同时涉及：

- Python
- Go
- TypeScript
- Docker
- 实时通信
- AI 模型服务

任何一个单独拿出来都能学很久，所以你的目标不是“一次学完”，而是“先能进入项目上下文”。

### 2. 一定要边运行边学习

只看教程、只看语法，进步会非常慢。这个项目最适合的方式是：

- 跑起来
- 请求接口
- 看返回
- 对照代码
- 做小改动
- 再验证

### 3. 优先做小改动，不要一开始就挑战真实模型接入

你最开始应该做的是：

- 改文案
- 改字段
- 改 stub 数据
- 改页面展示

而不是：

- 上来就接 LiveKit
- 上来就接 vLLM
- 上来就接 MuseTalk

### 4. 看不懂时，先问“这段代码的职责是什么”

不要一上来问“这段语法什么意思”，而是先问：

- 这个文件在整个项目里负责什么？
- 这个接口是给谁调用的？
- 这个字段为什么要存在？

你会更容易进入状态。

---

## 最后的判断

如果你的目标是：

- 把当前 AvaStack 骨架项目学明白
- 具备继续在这个仓库里做小功能和后续演进的能力

那么这份路线图是够用的。

如果你的目标是：

- 学完马上独立做出完整的数字人产品

那这份路线图还不够，因为当前仓库本身也还在骨架阶段。

所以请把你的目标先定成：

**先搞懂骨架、跑通流程、能做小改动，再逐步进入真实模型和实时链路。**

这是最稳、最不容易挫败的学习路径。
