# 服务拆分

## 控制面

### `services/orchestrator-go` / `avastack-orchestrator`

职责：

- 会话生命周期管理
- 策略决策
- 服务路由
- 鉴权集成
- 面向运维/业务的 API
- 全局健康状态聚合

不负责：

- 语音识别推理
- 语音合成推理
- 数字人渲染
- 任何 GPU 绑定的模型执行

## 模型面

### `services/model-asr-python` / `avastack-asr`

职责：

- 接收音频块
- 输出转写事件
- 暴露模型和运行时元数据

建议后续接入：

- SenseVoice

### `services/model-tts-python` / `avastack-tts`

职责：

- 接收文本合成请求
- 返回流式音频元数据和片段引用
- 暴露音色列表

建议后续接入：

- CosyVoice 2

### `services/model-avatar-python` / `avastack-avatar`

职责：

- 接收渲染任务
- 消费音频、viseme、timeline 等数据
- 返回渲染流元数据

建议后续接入：

- MuseTalk

### `services/model-llm-python` / `avastack-llm`

职责：

- 统一 prompt/messages 输入格式
- 代理到自托管 LLM 推理层
- 返回结构化结果

建议后续接入：

- Qwen behind vLLM

## 体验面

### `services/admin-web` / `avastack-admin`

职责：

- 会话面板
- 服务健康概览
- 运行时信息展示
- 手动联调和测试界面

## 基础设施层

### `infra/livekit`

- LiveKit 配置占位目录

### `infra/srs`

- RTMP/WebRTC 分发配置占位目录

### `infra/vllm`

- vLLM 部署说明目录

## 共享契约

### `shared/contracts`

- JSON 负载约定
- Session Schema
- 服务响应示例
- 错误响应约定
- 服务健康聚合结构

## 当前阶段优先级

第一阶段先完成：

1. 共享契约定稿
2. 控制面会话 API
3. 下游服务健康探测

第二阶段再推进：

1. LLM 网关接真实 vLLM/Qwen
2. TTS 接 CosyVoice 2
3. ASR 接 SenseVoice
4. 最后接数字人渲染
