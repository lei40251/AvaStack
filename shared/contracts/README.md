# 共享契约

这个目录用于定义服务之间共享的请求/响应约定。

## 核心原则

- 即使底层模型后端发生变化，请求/响应包裹结构也尽量保持稳定。
- 每次推理响应都带上运行时元数据。
- 控制面的 `session_id` 和传输层的房间/流标识要明确区分。

## 通用响应包裹

所有控制面和模型服务的 HTTP JSON 响应，默认遵循以下外层结构：

```json
{
  "request_id": "req_123",
  "session_id": "sess_123",
  "status": "ok",
  "data": {},
  "meta": {
    "service": "avastack-asr",
    "backend": "stub",
    "runtime": "cpu"
  }
}
```

字段说明：

- `request_id`：本次请求的唯一标识，用于日志串联。
- `session_id`：如果当前请求已经绑定会话，则必须返回；否则可以省略或置空。
- `status`：建议使用 `ok`、`accepted`、`created`、`error`。
- `data`：业务数据主体。
- `meta`：服务名、后端名、运行时等元数据。

## 错误响应约定

控制面和模型服务出错时，返回如下结构：

```json
{
  "request_id": "req_123",
  "status": "error",
  "error": {
    "code": "method_not_allowed",
    "message": "method not allowed"
  },
  "meta": {
    "service": "avastack-orchestrator"
  }
}
```

建议的错误码：

- `bad_request`
- `not_found`
- `method_not_allowed`
- `upstream_unavailable`
- `internal_error`

## Session Schema

控制面返回的 session 对象建议固定为如下结构：

```json
{
  "session_id": "sess_123",
  "status": "created",
  "mode": "text_chat",
  "avatar_id": "default-avatar",
  "transport": {
    "kind": "livekit",
    "livekit_ws_url": "ws://livekit:7880"
  },
  "created_at": "2026-06-11T10:00:00Z",
  "updated_at": "2026-06-11T10:00:00Z"
}
```

字段约定：

- `status`：当前先定义 `created`、`ready`、`active`、`closed`。
- `mode`：当前先定义 `text_chat`、`voice_chat`。
- `avatar_id`：控制面选中的数字人形象标识。
- `transport.kind`：默认 `livekit`，后续可扩展。

## 会话创建请求

`POST /v1/sessions`

```json
{
  "mode": "text_chat",
  "avatar_id": "default-avatar",
  "user_id": "user_123",
  "metadata": {
    "tenant": "demo"
  }
}
```

当前约束：

- `mode` 可缺省，默认 `text_chat`
- `avatar_id` 可缺省，默认 `default-avatar`
- `metadata` 保留为开放字段，但当前控制面不做复杂校验

## 会话列表响应

`GET /v1/sessions`

```json
{
  "request_id": "req_123",
  "status": "ok",
  "data": {
    "items": [
      {
        "session_id": "sess_123",
        "status": "created",
        "mode": "text_chat"
      }
    ],
    "total": 1
  }
}
```

## 会话更新请求

`PATCH /v1/sessions/{session_id}`

```json
{
  "status": "active",
  "avatar_id": "avatar-a",
  "metadata": {
    "tenant": "demo"
  }
}
```

当前约束：

- `status` 当前允许控制面自由写入，但建议先限制在 `created`、`ready`、`active`、`closed`
- `avatar_id` 可用于控制面切换当前会话的数字人配置
- `metadata` 当前采用整体覆盖，不做局部 merge

当前控制面已实现的状态流转约束：

- `created -> ready`
- `created -> closed`
- `ready -> active`
- `ready -> closed`
- `active -> closed`
- 同状态重复写入允许通过

## 服务健康聚合响应

`GET /v1/services/health`

```json
{
  "request_id": "req_123",
  "status": "ok",
  "data": {
    "services": [
      {
        "name": "asr",
        "base_url": "http://avastack-asr:8101",
        "healthy": true,
        "status_code": 200
      }
    ]
  }
}
```

## 当前阶段的约束边界

- 先固定控制面和模型服务的请求/响应格式。
- 先用内存态会话存储，后续再引入持久化。
- 先把服务健康聚合作为可观测入口，后续再接统一监控。
