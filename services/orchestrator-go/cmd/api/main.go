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
