// Package controlplane 实现编排层控制面的核心领域模型。
//
// 本包包含：
//   - 会话（Session）的数据结构与内存存储
//   - 会话生命周期状态机
//   - 下游 AI 服务的健康检查聚合
package controlplane

import "time"

// SessionTransport 描述会话使用的媒体传输通道信息。
type SessionTransport struct {
	Kind         string `json:"kind"`                    // 传输类型，目前固定为 "livekit"
	LiveKitWSURL string `json:"livekit_ws_url,omitempty"` // LiveKit WebSocket 信令地址
}

// Session 是编排层控制面的核心聚合根，代表一个端到端 AI 会话。
// 会话从创建开始，经过 ready → active 状态流转，最终进入 closed。
type Session struct {
	SessionID string            `json:"session_id"`          // 全局唯一会话标识
	Status    string            `json:"status"`              // 当前状态：created / ready / active / closed
	Mode      string            `json:"mode"`                // 交互模式，如 text_chat / voice_chat
	AvatarID  string            `json:"avatar_id"`           // 关联的数字人形象 ID
	UserID    string            `json:"user_id,omitempty"`   // 发起会话的用户标识
	Metadata  map[string]string `json:"metadata,omitempty"`  // 扩展元数据，由上游调用方填充
	Transport SessionTransport  `json:"transport"`           // 媒体传输配置
	CreatedAt time.Time         `json:"created_at"`          // 会话创建时间（UTC）
	UpdatedAt time.Time         `json:"updated_at"`          // 最近一次更新时间（UTC）
}

// CreateSessionRequest 是 POST /v1/sessions 的请求体。
type CreateSessionRequest struct {
	Mode     string            `json:"mode"`     // 交互模式，默认 "text_chat"
	AvatarID string            `json:"avatar_id"` // 数字人形象 ID
	UserID   string            `json:"user_id"`   // 用户标识
	Metadata map[string]string `json:"metadata"`  // 扩展元数据
}

// UpdateSessionRequest 是 PATCH /v1/sessions/{id} 的请求体。
// 所有字段均为可选，仅更新非零值字段。
type UpdateSessionRequest struct {
	Status   string            `json:"status"`    // 目标状态，需符合状态机规则
	AvatarID string            `json:"avatar_id"` // 新的数字人形象 ID
	Metadata map[string]string `json:"metadata"`  // 新的扩展元数据（全量替换）
}

// ServiceHealth 描述一个下游 AI 服务的即时健康状态。
type ServiceHealth struct {
	Name       string `json:"name"`                  // 服务名称，如 asr / tts / llm / avatar
	BaseURL    string `json:"base_url"`              // 服务基地址
	Healthy    bool   `json:"healthy"`               // 是否健康（HTTP 2xx）
	StatusCode int    `json:"status_code,omitempty"` // 最近一次健康检查的 HTTP 状态码
	Error      string `json:"error,omitempty"`       // 健康检查失败时的错误信息
}
