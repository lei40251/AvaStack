package controlplane

import "time"

type SessionTransport struct {
	Kind         string `json:"kind"`
	LiveKitWSURL string `json:"livekit_ws_url,omitempty"`
}

type Session struct {
	SessionID string            `json:"session_id"`
	Status    string            `json:"status"`
	Mode      string            `json:"mode"`
	AvatarID  string            `json:"avatar_id"`
	UserID    string            `json:"user_id,omitempty"`
	Metadata  map[string]string `json:"metadata,omitempty"`
	Transport SessionTransport  `json:"transport"`
	CreatedAt time.Time         `json:"created_at"`
	UpdatedAt time.Time         `json:"updated_at"`
}

type CreateSessionRequest struct {
	Mode     string            `json:"mode"`
	AvatarID string            `json:"avatar_id"`
	UserID   string            `json:"user_id"`
	Metadata map[string]string `json:"metadata"`
}

type UpdateSessionRequest struct {
	Status   string            `json:"status"`
	AvatarID string            `json:"avatar_id"`
	Metadata map[string]string `json:"metadata"`
}

type ServiceHealth struct {
	Name       string `json:"name"`
	BaseURL    string `json:"base_url"`
	Healthy    bool   `json:"healthy"`
	StatusCode int    `json:"status_code,omitempty"`
	Error      string `json:"error,omitempty"`
}
