// src/routes/health.ts
// GET /healthz —— 服务自检

import { Hono } from "hono";

const startTime = Date.now();

export const healthRoute = new Hono();

healthRoute.get("/healthz", (c) => {
  const uptimeSeconds = Math.floor((Date.now() - startTime) / 1000);
  return c.json({
    status: "ok",
    uptime_seconds: uptimeSeconds,
  });
});
