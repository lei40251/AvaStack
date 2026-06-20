// src/routes/info.ts
// GET /v1/info —— 服务信息 + 下游地址

import { Hono } from "hono";
import type { DownstreamRegistry } from "../services/downstream.js";

export function createInfoRoute(downstream: DownstreamRegistry): Hono {
  const app = new Hono();

  app.get("/v1/info", (c) => {
    const requestId = c.get("requestId") ?? "unknown";
    const start = Date.now();

    return c.json({
      request_id: requestId,
      status: "ok",
      data: {
        service: "avastack-orchestrator",
        version: "0.1.0",
        downstream: downstream.getDownstreamUrls(),
      },
      meta: {
        at: new Date().toISOString(),
        took_ms: Date.now() - start,
      },
    });
  });

  return app;
}
