package controlplane

import (
	"crypto/rand"
	"encoding/hex"
	"sort"
	"sync"
	"time"
)

type SessionStore struct {
	mu       sync.RWMutex
	sessions map[string]Session
}

func NewSessionStore() *SessionStore {
	return &SessionStore{
		sessions: make(map[string]Session),
	}
}

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

func (s *SessionStore) Get(sessionID string) (Session, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	session, ok := s.sessions[sessionID]
	return session, ok
}

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

func defaultString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func randomHex(size int) string {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return time.Now().UTC().Format("20060102150405")
	}
	return hex.EncodeToString(buf)
}
