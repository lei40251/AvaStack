// src/app.ts
// Hono 应用装配：中间件注册 + 路由挂载 + 依赖注入

import { Hono } from "hono";
import { requestId } from "./middleware/request-id.js";
import { corsMiddleware } from "./middleware/cors.js";
import { errorHandler } from "./middleware/error-handler.js";
import { healthRoute } from "./routes/health.js";
import { createInfoRoute } from "./routes/info.js";
import { createServicesRoute } from "./routes/services.js";
import { createSessionsRoute } from "./routes/sessions.js";
import { loadConfig } from "./config/env.js";
import { SessionStore } from "./services/session-store.js";
import { DownstreamRegistry } from "./services/downstream.js";
import { getDb } from "./services/db.js";

export function createApp() {
  const config = loadConfig();

  // 初始化数据库连接
  getDb(config.dbPath);

  // 初始化服务（依赖注入）
  const sessionStore = new SessionStore();
  const downstream = new DownstreamRegistry(config);

  // 装配 Hono 应用
  const app = new Hono();

  // 中间件（注册顺序影响执行顺序）
  app.use("*", corsMiddleware);
  app.use("*", requestId);

  // 路由挂载
  app.route("/", healthRoute);
  app.route("/", createInfoRoute(downstream));
  app.route("/", createServicesRoute(downstream));
  app.route("/", createSessionsRoute(sessionStore));

  // 错误处理（最后注册）
  app.onError(errorHandler);

  return app;
}
