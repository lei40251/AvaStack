package controlplane

import (
	"crypto/rand"
	"encoding/hex"
	"sort"
	"sync"
	"time"
)

// SessionStore 是会话的内存态存储实现。
// 内部使用读写锁保护并发访问，适用于单实例部署场景。
// 后续可替换为 Redis 或数据库实现相同的存取接口。
type SessionStore struct {
	mu       sync.RWMutex
	sessions map[string]Session
}

// NewSessionStore 创建一个空的会话存储实例。
func NewSessionStore() *SessionStore {
	return &SessionStore{
		sessions: make(map[string]Session),
	}
}

// Create 根据请求参数创建一个新会话，自动分配唯一 ID 并设置初始状态为 "created"。
func (s *SessionStore) Create(req CreateSessionRequest, liveKitWSURL string) Session {
	now := time.Now().UTC()
	session := Session{
		SessionID: "sess_" + randomHex(8),
		Status:    "created",
		Mode:      defaultString(req.Mode, "text_chat"),
		AvatarID:  defaultString(req.AvatarID, "default-avatar"),
		UserID:    req.UserID,
		Metadata:  req.Metadata,
		Transport: SessionTransport{
			Kind:         "livekit",
			LiveKitWSURL: liveKitWSURL,
		},
		CreatedAt: now,
		UpdatedAt: now,
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.sessions[session.SessionID] = session
	return session
}

// Get 按会话 ID 查找会话，第二个返回值为 false 表示未找到。
func (s *SessionStore) Get(sessionID string) (Session, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	session, ok := s.sessions[sessionID]
	return session, ok
}

// List 返回所有会话的切片，按创建时间倒序排列。
func (s *SessionStore) List() []Session {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]Session, 0, len(s.sessions))
	for _, session := range s.sessions {
		items = append(items, session)
	}

	sort.Slice(items, func(i, j int) bool {
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})
	return items
}

// Update 按会话 ID 更新会话的部分字段。
// 仅更新请求中非零值的字段，并校验状态迁移的合法性。
// 第二个返回值为 false 表示更新失败（会话不存在或状态迁移非法）。
func (s *SessionStore) Update(sessionID string, req UpdateSessionRequest) (Session, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	session, ok := s.sessions[sessionID]
	if !ok {
		return Session{}, false
	}

	if req.Status != "" {
		if !IsValidStatus(req.Status) || !CanTransitStatus(session.Status, req.Status) {
			return Session{}, false
		}
		session.Status = req.Status
	}
	if req.AvatarID != "" {
		session.AvatarID = req.AvatarID
	}
	if req.Metadata != nil {
		session.Metadata = req.Metadata
	}
	session.UpdatedAt = time.Now().UTC()
	s.sessions[sessionID] = session
	return session, true
}

// defaultString 在 value 为空时返回 fallback，相当于环境变量的默认值模式。
func defaultString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// randomHex 生成 size 字节的加密安全随机数的十六进制表示。
// 在随机数生成失败时降级为时间戳字符串，保证调用不会阻塞。
func randomHex(size int) string {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return time.Now().UTC().Format("20060102150405")
	}
	return hex.EncodeToString(buf)
}
