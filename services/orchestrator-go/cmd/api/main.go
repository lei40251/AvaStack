// Package main 是 AvaStack 编排层（orchestrator）的进程入口。
// 负责加载配置、组装 HTTP 路由并启动控制面服务。
package main

import (
	"log"
	"net/http"

	"avastack/services/orchestrator-go/internal/config"
	"avastack/services/orchestrator-go/internal/httpapi"
)

func main() {
	cfg := config.Load()
	server := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: httpapi.NewRouter(cfg),
	}

	log.Printf("avastack-orchestrator listening on :%s", cfg.Port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
