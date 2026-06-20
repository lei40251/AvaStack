// src/routes/services.ts
// GET /v1/services/health —— 聚合下游服务健康状态

import { Hono } from "hono";
import type { DownstreamRegistry } from "../services/downstream.js";

export function createServicesRoute(downstream: DownstreamRegistry): Hono {
  const app = new Hono();

  app.get("/v1/services/health", async (c) => {
    const requestId = c.get("requestId") ?? "unknown";
    const start = Date.now();

    const health = await downstream.checkAll();

    return c.json({
      request_id: requestId,
      status: "ok",
      data: health,
      meta: {
        at: new Date().toISOString(),
        took_ms: Date.now() - start,
      },
    });
  });

  return app;
}
