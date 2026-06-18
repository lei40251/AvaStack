package controlplane

import (
	"context"
	"net/http"
	"time"
)

// ServiceRegistry 管理所有下游 AI 服务的地址注册与健康检查。
// 每个注册的服务需暴露 /healthz 端点，由 Health 方法统一探测。
type ServiceRegistry struct {
	client   *http.Client      // 带超时的 HTTP 客户端
	services map[string]string // 服务名 → 基地址
}

// NewServiceRegistry 根据服务名到基地址的映射创建一个 ServiceRegistry。
func NewServiceRegistry(services map[string]string) *ServiceRegistry {
	return &ServiceRegistry{
		client: &http.Client{
			Timeout: 2 * time.Second, // 健康检查超时设为 2 秒，避免上游阻塞
		},
		services: services,
	}
}

// Health 对所有已注册服务执行健康检查，返回每个服务的即时状态。
func (r *ServiceRegistry) Health(ctx context.Context) []ServiceHealth {
	items := make([]ServiceHealth, 0, len(r.services))
	for name, baseURL := range r.services {
		items = append(items, r.check(ctx, name, baseURL))
	}
	return items
}

// check 对单个服务的 /healthz 端点执行一次 GET 探测。
// 2xx 状态码视为健康，网络错误或非 2xx 均标记为不健康并携带错误信息。
func (r *ServiceRegistry) check(ctx context.Context, name, baseURL string) ServiceHealth {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/healthz", nil)
	if err != nil {
		return ServiceHealth{
			Name:    name,
			BaseURL: baseURL,
			Healthy: false,
			Error:   err.Error(),
		}
	}

	resp, err := r.client.Do(req)
	if err != nil {
		return ServiceHealth{
			Name:    name,
			BaseURL: baseURL,
			Healthy: false,
			Error:   err.Error(),
		}
	}
	defer resp.Body.Close()

	return ServiceHealth{
		Name:       name,
		BaseURL:    baseURL,
		Healthy:    resp.StatusCode >= 200 && resp.StatusCode < 300,
		StatusCode: resp.StatusCode,
	}
}
