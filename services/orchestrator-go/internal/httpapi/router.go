package httpapi

import (
	"crypto/rand"
	"encoding/json"
	"encoding/hex"
	"net/http"
	"strings"
	"time"

	"avastack/services/orchestrator-go/internal/config"
	"avastack/services/orchestrator-go/internal/controlplane"
)

type Router struct {
	cfg          config.Config
	sessionStore *controlplane.SessionStore
	services     *controlplane.ServiceRegistry
}

// NewRouter 负责组装编排层当前阶段的最小 HTTP 路由。
func NewRouter(cfg config.Config) http.Handler {
	r := &Router{
		cfg:          cfg,
		sessionStore: controlplane.NewSessionStore(),
		services:     controlplane.NewServiceRegistry(map[string]string{
			"asr":    cfg.ASRBaseURL,
			"tts":    cfg.TTSBaseURL,
			"avatar": cfg.AvatarBaseURL,
			"llm":    cfg.LLMBaseURL,
		}),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", r.healthz)
	mux.HandleFunc("/v1/info", r.info)
	mux.HandleFunc("/v1/sessions", r.handleSessions)
	mux.HandleFunc("/v1/sessions/", r.sessionByID)
	mux.HandleFunc("/v1/services/health", r.servicesHealth)
	return mux
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PATCH,OPTIONS")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"request_id": newRequestID(),
		"status":     "error",
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
		"meta": map[string]string{
			"service": "avastack-orchestrator",
		},
	})
}

func newRequestID() string {
	buf := make([]byte, 6)
	if _, err := rand.Read(buf); err != nil {
		return "req_fallback"
	}
	return "req_" + hex.EncodeToString(buf)
}

// healthz 只反映当前编排层进程自身是否可用。
func (r *Router) healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "avastack-orchestrator",
		"time":    time.Now().UTC().Format(time.RFC3339),
	})
}

// info 返回当前编排层所依赖的下游服务和媒体基础设施地址。
func (r *Router) info(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"service": "avastack-orchestrator",
		"contract_version": "v1",
		"stack": map[string]string{
			"asr":    r.cfg.ASRBaseURL,
			"tts":    r.cfg.TTSBaseURL,
			"avatar": r.cfg.AvatarBaseURL,
			"llm":    r.cfg.LLMBaseURL,
		},
		"transport": map[string]string{
			"livekit": r.cfg.LiveKitWSURL,
			"srs":     r.cfg.SRSRTCBaseURL,
		},
	})
}

// handleSessions 统一处理会话集合资源的读写入口，避免路由层和存储字段重名。
func (r *Router) handleSessions(w http.ResponseWriter, req *http.Request) {
	if req.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
		return
	}
	switch req.Method {
	case http.MethodPost:
		r.createSession(w, req)
	case http.MethodGet:
		r.listSessions(w, req)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
	}
}

// sessionByID 返回单个会话的当前控制面视图。
func (r *Router) sessionByID(w http.ResponseWriter, req *http.Request) {
	if req.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
		return
	}
	switch req.Method {
	case http.MethodGet:
		r.getSessionByID(w, req)
	case http.MethodPatch:
		r.updateSessionByID(w, req)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
	}
}

// getSessionByID 返回单个会话的当前控制面视图。
func (r *Router) getSessionByID(w http.ResponseWriter, req *http.Request) {
	sessionID := strings.TrimPrefix(req.URL.Path, "/v1/sessions/")
	if sessionID == "" || strings.Contains(sessionID, "/") {
		writeError(w, http.StatusNotFound, "not_found", "session not found")
		return
	}

	session, ok := r.sessionStore.Get(sessionID)
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "session not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"request_id": newRequestID(),
		"session_id": session.SessionID,
		"status":     "ok",
		"data":       session,
		"meta": map[string]string{
			"service": "avastack-orchestrator",
		},
	})
}

// listSessions 返回当前内存态会话列表，按创建时间倒序排列。
func (r *Router) listSessions(w http.ResponseWriter, _ *http.Request) {
	items := r.sessionStore.List()
	writeJSON(w, http.StatusOK, map[string]any{
		"request_id": newRequestID(),
		"status":     "ok",
		"data": map[string]any{
			"items": items,
			"total": len(items),
		},
		"meta": map[string]string{
			"service": "avastack-orchestrator",
		},
	})
}

// servicesHealth 聚合当前控制面依赖的下游服务健康状态。
func (r *Router) servicesHealth(w http.ResponseWriter, req *http.Request) {
	if req.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
		return
	}
	if req.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
		return
	}

	health := r.services.Health(req.Context())
	writeJSON(w, http.StatusOK, map[string]any{
		"request_id": newRequestID(),
		"status":     "ok",
		"data": map[string]any{
			"services": health,
		},
		"meta": map[string]string{
			"service": "avastack-orchestrator",
		},
	})
}

// createSession 是第一版控制面会话创建入口，当前采用内存态存储。
func (r *Router) createSession(w http.ResponseWriter, req *http.Request) {
	var payload controlplane.CreateSessionRequest
	if err := json.NewDecoder(req.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid json payload")
		return
	}

	session := r.sessionStore.Create(payload, r.cfg.LiveKitWSURL)
	writeJSON(w, http.StatusCreated, map[string]any{
		"request_id": newRequestID(),
		"session_id": session.SessionID,
		"status": "created",
		"data": map[string]any{
			"session": session,
			"control_api": "/v1/sessions/" + session.SessionID,
		},
		"meta": map[string]string{
			"service": "avastack-orchestrator",
		},
	})
}

// updateSessionByID 用于更新会话的控制面状态，当前支持状态和 avatar_id 变更。
func (r *Router) updateSessionByID(w http.ResponseWriter, req *http.Request) {
	sessionID := strings.TrimPrefix(req.URL.Path, "/v1/sessions/")
	if sessionID == "" || strings.Contains(sessionID, "/") {
		writeError(w, http.StatusNotFound, "not_found", "session not found")
		return
	}

	var payload controlplane.UpdateSessionRequest
	if err := json.NewDecoder(req.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid json payload")
		return
	}

	session, ok := r.sessionStore.Update(sessionID, payload)
	if !ok {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid session update or session not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"request_id": newRequestID(),
		"session_id": session.SessionID,
		"status":     "ok",
		"data":       session,
		"meta": map[string]string{
			"service": "avastack-orchestrator",
		},
	})
}
