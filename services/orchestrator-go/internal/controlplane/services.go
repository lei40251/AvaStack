package controlplane

import (
	"context"
	"net/http"
	"time"
)

type ServiceRegistry struct {
	client   *http.Client
	services map[string]string
}

func NewServiceRegistry(services map[string]string) *ServiceRegistry {
	return &ServiceRegistry{
		client: &http.Client{
			Timeout: 2 * time.Second,
		},
		services: services,
	}
}

func (r *ServiceRegistry) Health(ctx context.Context) []ServiceHealth {
	items := make([]ServiceHealth, 0, len(r.services))
	for name, baseURL := range r.services {
		items = append(items, r.check(ctx, name, baseURL))
	}
	return items
}

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

