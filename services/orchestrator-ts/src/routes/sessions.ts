// src/routes/sessions.ts
// POST/GET/PATCH /v1/sessions —— 会话 CRUD

import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";
import type { SessionStore } from "../services/session-store.js";
import { SessionNotFoundError } from "../services/session-store.js";
import { InvalidTransitionError } from "../state/state-machine.js";

const createSchema = z.object({
  title: z.string().optional().default(""),
  metadata: z.record(z.unknown()).optional().default({}),
});

const updateSchema = z.object({
  status: z.enum(["ready", "active", "closed"]),
});

export function createSessionsRoute(store: SessionStore): Hono {
  const app = new Hono();

  // POST /v1/sessions —— 创建会话
  app.post("/v1/sessions", zValidator("json", createSchema), (c) => {
    const requestId = c.get("requestId") ?? "unknown";
    const start = Date.now();
    const body = c.req.valid("json");

    const session = store.create(body.title, body.metadata);

    return c.json(
      {
        request_id: requestId,
        session_id: session.id,
        status: "ok",
        data: session,
        meta: {
          at: new Date().toISOString(),
          took_ms: Date.now() - start,
        },
      },
      201
    );
  });

  // GET /v1/sessions —— 会话列表
  app.get("/v1/sessions", (c) => {
    const requestId = c.get("requestId") ?? "unknown";
    const start = Date.now();

    const sessions = store.list();

    return c.json({
      request_id: requestId,
      status: "ok",
      data: sessions,
      meta: {
        at: new Date().toISOString(),
        took_ms: Date.now() - start,
      },
    });
  });

  // GET /v1/sessions/:id —— 会话详情
  app.get("/v1/sessions/:id", (c) => {
    const requestId = c.get("requestId") ?? "unknown";
    const start = Date.now();
    const id = c.req.param("id");

    const session = store.getById(id);
    if (!session) {
      return c.json(
        {
          request_id: requestId,
          status: "error",
          error: {
            code: "SESSION_NOT_FOUND",
            message: `会话不存在: ${id}`,
          },
          meta: {
            at: new Date().toISOString(),
            took_ms: Date.now() - start,
          },
        },
        404
      );
    }

    return c.json({
      request_id: requestId,
      session_id: session.id,
      status: "ok",
      data: session,
      meta: {
        at: new Date().toISOString(),
        took_ms: Date.now() - start,
      },
    });
  });

  // PATCH /v1/sessions/:id —— 状态流转
  app.patch("/v1/sessions/:id", zValidator("json", updateSchema), (c) => {
    const requestId = c.get("requestId") ?? "unknown";
    const start = Date.now();
    const id = c.req.param("id");
    const { status } = c.req.valid("json");

    try {
      const session = store.updateStatus(id, status);
      return c.json({
        request_id: requestId,
        session_id: session.id,
        status: "ok",
        data: session,
        meta: {
          at: new Date().toISOString(),
          took_ms: Date.now() - start,
        },
      });
    } catch (err) {
      if (err instanceof SessionNotFoundError) {
        return c.json(
          {
            request_id: requestId,
            status: "error",
            error: { code: err.code, message: err.message },
            meta: { at: new Date().toISOString(), took_ms: Date.now() - start },
          },
          404
        );
      }
      if (err instanceof InvalidTransitionError) {
        return c.json(
          {
            request_id: requestId,
            status: "error",
            error: { code: err.code, message: err.message },
            meta: { at: new Date().toISOString(), took_ms: Date.now() - start },
          },
          400
        );
      }
      throw err;
    }
  });

  return app;
}
