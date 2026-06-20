// src/middleware/error-handler.ts
// 统一错误响应，格式遵循 ApiErrorBody 契约

import type { ErrorHandler } from "hono";

export const errorHandler: ErrorHandler = (err, c) => {
  const requestId = c.get("requestId") ?? "unknown";
  console.error(`[${requestId}]`, err);

  // HTTPException（如 404）使用自带 status
  if ("getResponse" in err && typeof (err as any).getResponse === "function") {
    return (err as any).getResponse();
  }

  return c.json(
    {
      request_id: requestId,
      status: "error",
      error: {
        code: "INTERNAL_ERROR",
        message: err.message ?? "Internal server error",
      },
      meta: {
        at: new Date().toISOString(),
        took_ms: 0,
      },
    },
    500
  );
};
