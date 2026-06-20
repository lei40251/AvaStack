// src/middleware/request-id.ts
// 为每个请求注入唯一的 request_id，写入 ctx 供后续使用

import { createMiddleware } from "hono/factory";

export const requestId = createMiddleware(async (c, next) => {
  c.set("requestId", crypto.randomUUID());
  await next();
});
