# AvaStack

元述（`AvaStack`）数字人平台，是一个重新起步的仓库，用来承载面向长期私有化部署的数字人能力底座。

这个分支已经刻意移除了之前的原型代码，改成面向长期演进的服务化骨架，核心技术方向如下：

- `Python`：模型相关服务
- `Go`：编排层和业务 API
- `TypeScript`：管理后台
- `LiveKit`：实时音视频传输
- `SRS`：可选的 RTMP/HLS 分发
- `vLLM`：自托管 LLM 推理

## 仓库结构

```text
docs/
infra/
services/
shared/
```

- [docs/architecture.md](/D:/Gitlab/xavatar/docs/architecture.md)
- [docs/service-decomposition.md](/D:/Gitlab/xavatar/docs/service-decomposition.md)
- [compose.yaml](/D:/Gitlab/xavatar/compose.yaml)

## 服务清单

- `avastack-orchestrator`：目录 `services/orchestrator-go`，负责会话编排、服务路由、控制面 API
- `avastack-asr`：目录 `services/model-asr-python`，负责 ASR 服务边界
- `avastack-tts`：目录 `services/model-tts-python`，负责 TTS 服务边界
- `avastack-avatar`：目录 `services/model-avatar-python`，负责数字人渲染服务边界
- `avastack-llm`：目录 `services/model-llm-python`，负责 LLM 网关边界
- `avastack-admin`：目录 `services/admin-web`，负责运维/管理控制台

## 本地开发

1. 先看 [docs/architecture.md](/D:/Gitlab/xavatar/docs/architecture.md)
2. 再看 [docs/service-decomposition.md](/D:/Gitlab/xavatar/docs/service-decomposition.md)
3. 将 `.env.example` 复制为 `.env`
4. 运行 `docker compose up --build` 启动当前的骨架服务

推荐直接运行：

- PowerShell：`./start.ps1`
- CMD：`start.bat`

`start.ps1` 当前负责正式骨架模式启动，执行逻辑如下：

1. 默认模式：`./start.ps1`
   - 先检测 `docker`
   - 不只检测 `docker` 命令，还会检测 Docker daemon 是否真的可连接
   - 在开始安装容器运行时前，会先询问一次是否需要设置代理
   - 如果缺失，则优先尝试直链下载 `Rancher Desktop` 的 MSI 并静默安装
   - 脚本会输出自己的阶段进度，明确显示检测、下载、回退安装、等待 daemon 等状态
   - 下载 `Rancher Desktop` 时会直接显示下载链接、真实下载进度和已下载大小
   - 如果 `Rancher Desktop` 安装失败，再回退尝试 `Docker Desktop`
   - 如果 `winget` 不可用或都失败，再回退到 `scoop install docker`
   - 如果检测到已安装 `Rancher Desktop` 或 `Docker Desktop` 但后台未启动，脚本会先尝试自动启动并等待初始化
   - 如果下载失败且你有代理，脚本会提示你输入代理地址后重试
   - 如果 `docker` 仍不可用，则输出安装指引
   - 如果 `docker` 可用，则进入 `docker compose up --build`
2. 正式本地开发模式：`./start.ps1 -Mode local`
   - 先一次性检测 `go`、`node/npm`、`python/pip`
   - 如果缺失，会先统一尝试安装本地工具链
   - 工具链就绪后，再统一安装 Go / Node / Python 代码依赖
   - 如果下载失败且你有代理，脚本会提示你输入代理地址后重试
   - 如果缺失或安装失败，则输出明确安装说明

启动完成后，建议按下面顺序验证：

1. 打开管理台：`http://localhost:4173`
2. 查看编排层信息：`http://localhost:8080/v1/info`
3. 查看服务健康：`http://localhost:8080/v1/services/health`
4. 创建一个会话：

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/v1/sessions -ContentType "application/json" -Body '{"mode":"text_chat","avatar_id":"default-avatar","user_id":"demo-user"}'
```

当前仓库还是架构骨架，不是完整产品实现。现有接口故意保持最小化，并返回结构化的 stub 数据，目的是先把服务边界、编排关系和部署形态定清楚，再逐步接入真实模型能力。

## 当前可用控制面接口

`avastack-orchestrator` 当前已经提供第一版控制面接口：

- `GET /healthz`：编排层自身健康检查
- `GET /v1/info`：查看当前编排层配置和下游依赖
- `GET /v1/services/health`：聚合下游模型服务健康状态
- `POST /v1/sessions`：创建会话
- `GET /v1/sessions`：列出当前会话
- `GET /v1/sessions/{session_id}`：查询单个会话
- `PATCH /v1/sessions/{session_id}`：更新会话状态或 avatar 配置

相关契约说明见 [shared/contracts/README.md](/D:/Gitlab/xavatar/shared/contracts/README.md)。

## 当前启动后的访问入口

- 正式骨架模式：管理台 `http://localhost:4173`，编排层 `http://localhost:8080`
- LiveKit：`ws://localhost:7880`
- SRS HTTP 管理口：`http://localhost:1985`
