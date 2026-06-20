# AvaStack

元述（`AvaStack`）数字人平台，是一个重新起步的仓库，用来承载面向长期私有化部署的数字人能力底座。

这个分支已经刻意移除了之前的原型代码，改成面向长期演进的服务化骨架，核心技术方向如下：

- `Python`：模型相关服务
- `TypeScript`：编排层、业务 API 和管理后台
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

- [docs/architecture.md](docs/architecture.md)
- [docs/service-decomposition.md](docs/service-decomposition.md)
- [compose.yaml](compose.yaml)

## 服务清单

- `avastack-orchestrator`：目录 `services/orchestrator-ts`，负责会话编排、服务路由、控制面 API（TypeScript + Hono + SQLite）
- `avastack-asr`：目录 `services/model-asr-python`，负责 ASR 服务边界
- `avastack-tts`：目录 `services/model-tts-python`，负责 TTS 服务边界
- `avastack-avatar`：目录 `services/model-avatar-python`，负责数字人渲染服务边界
- `avastack-llm`：目录 `services/model-llm-python`，负责 LLM 网关边界
- `avastack-admin`：目录 `services/admin-web`，负责运维/管理控制台

## 本地开发

1. 先看 [docs/architecture.md](docs/architecture.md)
2. 再看 [docs/service-decomposition.md](docs/service-decomposition.md)
3. 将 `.env.example` 复制为 `.env`
4. 如需代理，先配置代理
5. 运行 `docker compose up --build` 或直接使用仓库内启动脚本，启动当前的骨架服务

推荐直接运行：

- PowerShell：`./start.ps1`
- CMD：`start.bat`

`start.ps1` 当前负责正式骨架模式启动，执行逻辑如下：

1. 默认模式：`./start.ps1`
   - 一次性检测 `docker`、`docker compose`、Docker daemon
   - 用表格形式汇总当前环境状态
   - 如果需要下载依赖，会先提醒你配置代理
   - 如果传入 `-Proxy`，会把代理注入到 `docker build` 阶段
   - 如果构建失败，会尽量区分是基础镜像拉取失败、代理连接失败，还是代码编译失败
   - 启动成功后会以后台模式拉起 compose，并直接打印访问入口表、端口映射表和启动完成文本图
   - 如果 `docker` 环境未就绪，则输出安装和修复指引
2. 正式本地开发模式：`./start.ps1 -Mode local`
   - 先一次性检测 `go`、`node/npm`、`python/pip`
   - 用表格形式一次性汇总缺失项和版本情况
   - 输出对应安装方式，以及 Go / Node / Python 项目依赖安装命令
   - 如果涉及下载，会提醒你先配置代理

启动完成后，建议按下面顺序验证：

1. 打开管理台：`http://localhost:54173`
2. 查看编排层信息：`http://localhost:58080/v1/info`
3. 查看服务健康：`http://localhost:58080/v1/services/health`
4. 创建一个会话：

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:58080/v1/sessions -ContentType "application/json" -Body '{"mode":"text_chat","avatar_id":"default-avatar","user_id":"demo-user"}'
```

当前仓库还是架构骨架，不是完整产品实现。现有接口故意保持最小化，并返回结构化的 stub 数据，目的是先把服务边界、编排关系和部署形态定清楚，再逐步接入真实模型能力。

如果你使用 `./start.ps1`，启动完成后命令行里会直接给出：

- 可访问地址表
- 端口与服务对应表
- 一份纯文本启动拓扑图
- 常用后续命令（`docker compose ps` / `docker compose logs -f` / `docker compose down`）

## 代理说明

如果你的网络访问 Docker Hub、PyPI 或 npm 需要代理，建议优先使用 PowerShell 显式设置：

```powershell
$env:HTTP_PROXY = "http://192.168.9.108:4781"
$env:HTTPS_PROXY = "http://192.168.9.108:4781"
./start.ps1 -Mode docker -Proxy "http://192.168.9.108:4781"
```

需要注意两层代理：

- Docker Desktop 拉基础镜像时，走的是 Docker daemon 侧代理；如果失败，通常需要在 Docker Desktop 的 `Settings -> Proxies` 里配置。
- `docker build` 里的 `pip install`、`npm install`、`go mod download`，会使用 `start.ps1 -Proxy ...` 注入的代理。

如果你的代理软件默认只监听 `127.0.0.1`，Docker 可能仍然无法访问。此时需要在代理软件里开启“允许局域网连接”或同类选项，让宿主机 IP 也能访问该代理端口。

## 端口覆盖

仓库里的基础设施端口现在都支持通过 `.env` 覆盖：

- `ORCHESTRATOR_PORT`：默认 `58080`
- `ASR_PORT`：默认 `58101`
- `TTS_PORT`：默认 `58102`
- `AVATAR_PORT`：默认 `58103`
- `LLM_PORT`：默认 `58104`
- `ADMIN_PORT`：默认 `54173`
- `LIVEKIT_PORT`：默认 `57880`
- `LIVEKIT_TCP_PORT`：默认 `57881`
- `LIVEKIT_UDP_PORT`：默认 `57882`
- `SRS_RTMP_PORT`：默认 `51935`
- `SRS_API_PORT`：默认 `51985`
- `SRS_HTTP_PORT`：默认 `58081`

如果宿主机已有端口占用，可以直接在 `.env` 中调整，例如：

```env
SRS_RTMP_PORT=61935
SRS_API_PORT=61985
SRS_HTTP_PORT=68081
```

然后重新执行：

```powershell
./start.ps1 -Mode docker -Proxy "http://192.168.9.108:4781"
```

## 常见问题

1. 如果出现 `Docker Desktop has no HTTPS proxy`
   - 说明失败发生在基础镜像拉取阶段，需要先去 Docker Desktop 里配置代理。
2. 如果出现 `Cannot connect to proxy` 或 `Connection refused`
   - 说明容器或 Docker daemon 访问不到你的代理地址，优先检查代理软件是否监听在宿主机可访问地址上，而不只是 `127.0.0.1`。
3. 如果出现 `bind: ... forbidden by its access permissions`
   - 说明宿主机端口冲突。仓库默认已经把原来的 4 位端口改成前缀 `5` 的 5 位端口；如果仍冲突，可继续在 `.env` 覆盖。

## 当前可用控制面接口

`avastack-orchestrator` 当前已经提供第一版控制面接口：

- `GET /healthz`：编排层自身健康检查
- `GET /v1/info`：查看当前编排层配置和下游依赖
- `GET /v1/services/health`：聚合下游模型服务健康状态
- `POST /v1/sessions`：创建会话
- `GET /v1/sessions`：列出当前会话
- `GET /v1/sessions/{session_id}`：查询单个会话
- `PATCH /v1/sessions/{session_id}`：更新会话状态或 avatar 配置

相关契约说明见 [shared/contracts/README.md](shared/contracts/README.md)。

## 当前启动后的访问入口

- `./start.ps1` 启动成功后，命令行里也会自动打印下面这些入口
- 正式骨架模式：管理台 `http://localhost:54173`，编排层 `http://localhost:58080`
- LiveKit：`ws://localhost:57880`
- SRS API：`http://localhost:51985`
- SRS HTTP：`http://localhost:58081`
