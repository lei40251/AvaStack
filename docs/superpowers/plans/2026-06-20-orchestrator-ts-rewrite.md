# Orchestrator-TS 重写实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 TypeScript + Hono + SQLite 重写 Go 调度服务，API 契约与当前 Go 版完全兼容

**Architecture:** Hono HTTP 框架作为路由层，状态机模块管理会话生命周期，Drizzle ORM 操作 SQLite 持久化会话，下游服务注册器聚合 4 个 AI 模型的健康状态

**Tech Stack:** Node.js 22, TypeScript 5.6, Hono 4, Drizzle ORM 0.36, better-sqlite3 11, Zod 3

**Design Doc:** `docs/superpowers/specs/2026-06-20-tech-stack-redesign-design.md`

**Background:** 当前 Go 版 `services/orchestrator-go/` 实现了相同 API，作为对照参考。本计划创建新的 `services/orchestrator-ts/`，完成后 Docker Compose 替换服务名，原 Go 版保留不动。

---

### Task 1: 项目脚手架

**Files:**
- Create: `services/orchestrator-ts/package.json`
- Create: `services/orchestrator-ts/tsconfig.json`
- Create: `services/orchestrator-ts/Dockerfile`
- Create: `services/orchestrator-ts/.dockerignore`
- Create: `services/orchestrator-ts/src/index.ts`（临时，验证脚手架可用）

- [ ] **Step 1: 创建 package.json**

```json
{
  "name": "@avastack/orchestrator-ts",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "db:push": "drizzle-kit push",
    "db:migrate": "drizzle-kit migrate"
  },
  "dependencies": {
    "hono": "^4.6.0",
    "drizzle-orm": "^0.36.0",
    "better-sqlite3": "^11.6.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.12",
    "typescript": "^5.6.0",
    "tsx": "^4.19.0",
    "@types/node": "^22.0.0",
    "drizzle-kit": "^0.28.0"
  }
}
```

- [ ] **Step 2: 创建 tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 3: 创建 Dockerfile（多阶段构建）**

```dockerfile
FROM node:22-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
RUN npm ci
COPY src/ ./src/
RUN npm run build

FROM node:22-alpine AS run
WORKDIR /app
RUN addgroup -S avastack && adduser -S avastack -G avastack
COPY --from=base /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
# SQLite 数据目录
RUN mkdir -p /data && chown avastack:avastack /data
USER avastack
EXPOSE 8080
ENV NODE_ENV=production
ENV DB_PATH=/data/avastack.db
CMD ["node", "dist/index.js"]
```

- [ ] **Step 4: 创建 .dockerignore**

```
node_modules
dist
*.db
*.db-journal
.env
```

- [ ] **Step 5: 创建临时入口验证脚手架**

```typescript
// src/index.ts
import { serve } from "@hono/node-server";

serve({ port: 8080, fetch: (req) => new Response("ok") });
console.log("Orchestrator-TS listening on :8080");
```

- [ ] **Step 6: 安装依赖并验证**

```bash
cd services/orchestrator-ts && npm install && npx tsx src/index.ts
```

Expected: 终端输出 `Orchestrator-TS listening on :8080`，另一终端 `curl http://localhost:8080` 返回 `ok`。

- [ ] **Step 7: Commit**

```bash
git add services/orchestrator-ts/
git commit -m "scaffold: orchestrator-ts 项目脚手架（Hono + SQLite + Docker）"
```

---

### Task 2: 共享类型定义

**Files:**
- Create: `services/orchestrator-ts/src/types/contracts.ts`

- [ ] **Step 1: 创建 contracts.ts（单一事实源）**

```typescript
// src/types/contracts.ts
// 前后端共享类型定义的唯一来源。管理后台直接 import 此文件。

// ====== 统一响应信封 ======

export interface ApiEnvelope<T> {
  request_id: string;
  session_id?: string;
  status: "ok";
  data: T;
  meta: {
    at: string;       // ISO 8601
    took_ms: number;
  };
}

export interface ApiErrorBody {
  request_id: string;
  status: "error";
  error: {
    code: string;
    message: string;
    detail?: unknown;
  };
  meta: {
    at: string;
    took_ms: number;
  };
}

// ====== 会话 ======

export type SessionStatus = "created" | "ready" | "active" | "closed";

export const VALID_STATUS_TRANSITIONS: Record<SessionStatus, SessionStatus[]> = {
  created: ["ready", "closed"],
  ready:   ["active", "closed"],
  active:  ["closed"],
  closed:  [],
};

export interface Session {
  id: string;
  status: SessionStatus;
  title: string;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  closed_at: string | null;
}

// ====== 请求体 ======

export interface CreateSessionRequest {
  title?: string;
  metadata?: Record<string, unknown>;
}

export interface UpdateSessionRequest {
  status: "ready" | "active" | "closed";
}

// ====== 服务健康 ======

export interface ServiceHealth {
  healthy: boolean;
  latency_ms: number | null;
  error?: string;
}

export interface ServicesHealthResponse {
  services: Record<string, ServiceHealth>;
}

// ====== Info ======

export interface InfoResponse {
  service: string;
  version: string;
  downstream: Record<string, string>;
}
```

- [ ] **Step 2: Commit**

```bash
git add services/orchestrator-ts/src/types/contracts.ts
git commit -m "feat: 定义共享类型契约 contracts.ts"
```

---

### Task 3: 配置模块

**Files:**
- Create: `services/orchestrator-ts/src/config/env.ts`

- [ ] **Step 1: 创建环境变量解析模块**

```typescript
// src/config/env.ts
// 根据 Go 版 internal/config/config.go 的环境变量约定改写

export interface AppConfig {
  port: number;
  downstream: {
    asr: string;
    tts: string;
    avatar: string;
    llm: string;
  };
  dbPath: string;
}

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
}

export function loadConfig(): AppConfig {
  return {
    port: parseInt(process.env["PORT"] ?? "8080", 10),
    downstream: {
      asr:    requireEnv("ASR_URL"),
      tts:    requireEnv("TTS_URL"),
      avatar: requireEnv("AVATAR_URL"),
      llm:    requireEnv("LLM_URL"),
    },
    dbPath: process.env["DB_PATH"] ?? ":memory:",
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add services/orchestrator-ts/src/config/env.ts
git commit -m "feat: 环境变量配置模块 env.ts"
```

---

### Task 4: 中间件

**Files:**
- Create: `services/orchestrator-ts/src/middleware/request-id.ts`
- Create: `services/orchestrator-ts/src/middleware/cors.ts`
- Create: `services/orchestrator-ts/src/middleware/error-handler.ts`

- [ ] **Step 1: request-id 中间件**

```typescript
// src/middleware/request-id.ts
import { createMiddleware } from "hono/factory";
import { randomUUID } from "node:crypto";

// 为每个请求注入唯一的 request_id，写入 ctx 供后续使用
export const requestId = createMiddleware(async (c, next) => {
  c.set("requestId", randomUUID());
  await next();
});
```

- [ ] **Step 2: CORS 中间件**

```typescript
// src/middleware/cors.ts
import { cors } from "hono/cors";

export const corsMiddleware = cors({
  origin: "*",
  allowMethods: ["GET", "POST", "PATCH", "OPTIONS"],
  allowHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400,
});
```

- [ ] **Step 3: 错误处理中间件**

```typescript
// src/middleware/error-handler.ts
import type { Context, ErrorHandler } from "hono";

// 统一错误响应，格式遵循 ApiErrorBody
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
```

- [ ] **Step 4: Commit**

```bash
git add services/orchestrator-ts/src/middleware/
git commit -m "feat: 中间件（request-id、CORS、统一错误处理）"
```

---

### Task 5: 会话状态机

**Files:**
- Create: `services/orchestrator-ts/src/state/state-machine.ts`

- [ ] **Step 1: 完整状态机模块**

```typescript
// src/state/state-machine.ts
import type { SessionStatus } from "../types/contracts.js";
import { VALID_STATUS_TRANSITIONS } from "../types/contracts.js";

export class InvalidTransitionError extends Error {
  public readonly code = "INVALID_TRANSITION";

  constructor(from: SessionStatus, to: SessionStatus) {
    super(`不允许从 ${from} 转换到 ${to}`);
    this.name = "InvalidTransitionError";
  }
}

// 校验状态流转是否合法
export function validateTransition(
  from: SessionStatus,
  to: SessionStatus
): void {
  const allowed = VALID_STATUS_TRANSITIONS[from];
  if (!allowed || !allowed.includes(to)) {
    throw new InvalidTransitionError(from, to);
  }
}

// 执行状态流转，返回新的状态和可能的时间戳更新
export function applyTransition(
  currentStatus: SessionStatus,
  targetStatus: SessionStatus
): {
  status: SessionStatus;
  closed_at: string | null;
} {
  validateTransition(currentStatus, targetStatus);

  const now = new Date().toISOString();
  const closed_at = targetStatus === "closed" ? now : null;

  return { status: targetStatus, closed_at };
}
```

- [ ] **Step 2: Commit**

```bash
git add services/orchestrator-ts/src/state/state-machine.ts
git commit -m "feat: 会话状态机（created→ready→active→closed）"
```

---

### Task 6: 会话持久化（SQLite + Drizzle）

**Files:**
- Create: `services/orchestrator-ts/src/services/db.ts`
- Create: `services/orchestrator-ts/src/services/session-store.ts`
- Create: `services/orchestrator-ts/drizzle.config.ts`

- [ ] **Step 1: 数据库连接 + Schema 定义**

```typescript
// src/services/db.ts
import Database from "better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

// ---- Schema ----

export const sessions = sqliteTable("sessions", {
  id:         text("id").primaryKey(),
  status:     text("status").notNull().default("created"),
  title:      text("title").notNull().default(""),
  metadata:   text("metadata").notNull().default("{}"),  // JSON string
  created_at: text("created_at").notNull(),
  updated_at: text("updated_at").notNull(),
  closed_at:  text("closed_at"),
});

export const serviceHealthLog = sqliteTable("service_health_log", {
  id:         integer("id").primaryKey({ autoIncrement: true }),
  service:    text("service").notNull(),
  healthy:    integer("healthy").notNull(),
  latency_ms: integer("latency_ms"),
  checked_at: text("checked_at").notNull(),
});

// ---- Connection ----

let dbInstance: ReturnType<typeof drizzle> | null = null;

export function getDb(dbPath?: string) {
  if (!dbInstance) {
    const path = dbPath ?? process.env["DB_PATH"] ?? ":memory:";
    const sqlite = new Database(path);
    sqlite.pragma("journal_mode = WAL");
    sqlite.pragma("foreign_keys = ON");
    dbInstance = drizzle(sqlite, { schema: { sessions, serviceHealthLog } });
    // 自动建表（开发期）
    initTables(sqlite);
  }
  return dbInstance;
}

function initTables(sqlite: Database.Database): void {
  sqlite.exec(`
    CREATE TABLE IF NOT EXISTS sessions (
      id         TEXT PRIMARY KEY,
      status     TEXT NOT NULL DEFAULT 'created',
      title      TEXT NOT NULL DEFAULT '',
      metadata   TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      closed_at  TEXT
    );

    CREATE TABLE IF NOT EXISTS service_health_log (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      service    TEXT NOT NULL,
      healthy    INTEGER NOT NULL,
      latency_ms INTEGER,
      checked_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);
}
```

- [ ] **Step 2: 会话存储服务**

```typescript
// src/services/session-store.ts
import { eq } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { getDb, sessions } from "./db.js";
import type { Session, SessionStatus } from "../types/contracts.js";
import { applyTransition } from "../state/state-machine.js";

export interface ISessionStore {
  create(title?: string, metadata?: Record<string, unknown>): Session;
  getById(id: string): Session | undefined;
  list(): Session[];
  updateStatus(id: string, target: SessionStatus): Session;
}

export class SessionStore implements ISessionStore {
  private db = getDb();

  create(title = "", metadata: Record<string, unknown> = {}): Session {
    const now = new Date().toISOString();
    const session: Session = {
      id: uuidv7(),
      status: "created",
      title,
      metadata,
      created_at: now,
      updated_at: now,
      closed_at: null,
    };

    this.db.insert(sessions).values({
      ...session,
      metadata: JSON.stringify(session.metadata),
    }).run();

    return session;
  }

  getById(id: string): Session | undefined {
    const row = this.db.select()
      .from(sessions)
      .where(eq(sessions.id, id))
      .get();

    return row ? rowToSession(row) : undefined;
  }

  list(): Session[] {
    const rows = this.db.select()
      .from(sessions)
      .orderBy(sessions.created_at)
      .all();

    return rows.map(rowToSession);
  }

  updateStatus(id: string, target: SessionStatus): Session {
    const current = this.getById(id);
    if (!current) {
      throw new SessionNotFoundError(id);
    }

    const { status, closed_at } = applyTransition(current.status, target);
    const now = new Date().toISOString();

    this.db.update(sessions)
      .set({ status, updated_at: now, closed_at })
      .where(eq(sessions.id, id))
      .run();

    // 重新读取以返回最新状态
    return this.getById(id)!;
  }
}

// 数据库行 → 领域对象
function rowToSession(row: any): Session {
  return {
    ...row,
    metadata: typeof row.metadata === "string"
      ? JSON.parse(row.metadata)
      : row.metadata,
  };
}

export class SessionNotFoundError extends Error {
  public readonly code = "SESSION_NOT_FOUND";
  constructor(id: string) {
    super(`会话不存在: ${id}`);
    this.name = "SessionNotFoundError";
  }
}
```

- [ ] **Step 3: drizzle.config.ts**

```typescript
// drizzle.config.ts
import type { Config } from "drizzle-kit";

export default {
  schema: "./src/services/db.ts",
  out: "./drizzle/migrations",
  dialect: "sqlite",
  dbCredentials: {
    url: process.env["DB_PATH"] ?? ":memory:",
  },
} satisfies Config;
```

- [ ] **Step 4: 安装 uuid 依赖**

```bash
cd services/orchestrator-ts && npm install uuid && npm install -D @types/uuid
```

- [ ] **Step 5: Commit**

```bash
git add services/orchestrator-ts/src/services/db.ts services/orchestrator-ts/src/services/session-store.ts services/orchestrator-ts/drizzle.config.ts services/orchestrator-ts/package.json
git commit -m "feat: SQLite 会话持久化（Drizzle ORM + better-sqlite3）"
```

---

### Task 7: 下游服务注册器

**Files:**
- Create: `services/orchestrator-ts/src/services/downstream.ts`

- [ ] **Step 1: 下游服务健康检查**

```typescript
// src/services/downstream.ts
import type { AppConfig } from "../config/env.js";
import type { ServiceHealth, ServicesHealthResponse } from "../types/contracts.js";

const HEALTH_TIMEOUT_MS = 5000;

// 注册的下游服务列表
interface DownstreamDef {
  name: string;
  url: string;
}

export class DownstreamRegistry {
  private services: DownstreamDef[];

  constructor(config: AppConfig) {
    this.services = [
      { name: "asr",    url: config.downstream.asr },
      { name: "tts",    url: config.downstream.tts },
      { name: "avatar", url: config.downstream.avatar },
      { name: "llm",    url: config.downstream.llm },
    ];
  }

  // 聚合所有下游服务健康状态
  async checkAll(): Promise<ServicesHealthResponse> {
    const results = await Promise.all(
      this.services.map((svc) => this.checkOne(svc))
    );

    const services: Record<string, ServiceHealth> = {};
    for (const r of results) {
      services[r.name] = r.health;
    }
    return { services };
  }

  private async checkOne(
    svc: DownstreamDef
  ): Promise<{ name: string; health: ServiceHealth }> {
    const start = Date.now();
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS);

      const resp = await fetch(`${svc.url}/healthz`, {
        signal: controller.signal,
      });
      clearTimeout(timer);

      const latency_ms = Date.now() - start;

      return {
        name: svc.name,
        health: {
          healthy: resp.ok,
          latency_ms,
        },
      };
    } catch (err: any) {
      return {
        name: svc.name,
        health: {
          healthy: false,
          latency_ms: null,
          error: err.message,
        },
      };
    }
  }

  // 供 /v1/info 接口使用，返回下游地址映射
  getDownstreamUrls(): Record<string, string> {
    const urls: Record<string, string> = {};
    for (const svc of this.services) {
      urls[svc.name] = svc.url;
    }
    return urls;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add services/orchestrator-ts/src/services/downstream.ts
git commit -m "feat: 下游服务注册器 + 健康检查聚合"
```

---

### Task 8: 路由 - Health & Info

**Files:**
- Create: `services/orchestrator-ts/src/routes/health.ts`
- Create: `services/orchestrator-ts/src/routes/info.ts`

- [ ] **Step 1: GET /healthz**

```typescript
// src/routes/health.ts
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
```

- [ ] **Step 2: GET /v1/info**

```typescript
// src/routes/info.ts
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
```

- [ ] **Step 3: Commit**

```bash
git add services/orchestrator-ts/src/routes/health.ts services/orchestrator-ts/src/routes/info.ts
git commit -m "feat: GET /healthz + GET /v1/info 路由"
```

---

### Task 9: 路由 - Services Health

**Files:**
- Create: `services/orchestrator-ts/src/routes/services.ts`

- [ ] **Step 1: GET /v1/services/health**

```typescript
// src/routes/services.ts
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
```

- [ ] **Step 2: Commit**

```bash
git add services/orchestrator-ts/src/routes/services.ts
git commit -m "feat: GET /v1/services/health 路由"
```

---

### Task 10: 路由 - Sessions（核心）

**Files:**
- Create: `services/orchestrator-ts/src/routes/sessions.ts`

- [ ] **Step 1: 完整的会话 CRUD 路由**

```typescript
// src/routes/sessions.ts
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

  // POST /v1/sessions
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

  // GET /v1/sessions
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

  // GET /v1/sessions/:id
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

  // PATCH /v1/sessions/:id
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
```

- [ ] **Step 2: 安装 @hono/zod-validator**

```bash
cd services/orchestrator-ts && npm install @hono/zod-validator
```

- [ ] **Step 3: Commit**

```bash
git add services/orchestrator-ts/src/routes/sessions.ts services/orchestrator-ts/package.json
git commit -m "feat: 会话 CRUD 路由（POST/GET/PATCH /v1/sessions）"
```

---

### Task 11: App 装配 + 入口

**Files:**
- Modify: `services/orchestrator-ts/src/app.ts`（Create）
- Modify: `services/orchestrator-ts/src/index.ts`（替换临时版本）

- [ ] **Step 1: Hono app 装配**

```typescript
// src/app.ts
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

  // 初始化数据库
  getDb(config.dbPath);

  // 初始化服务
  const sessionStore = new SessionStore();
  const downstream = new DownstreamRegistry(config);

  // 装配 app
  const app = new Hono();

  // 中间件（顺序重要）
  app.use("*", corsMiddleware);
  app.use("*", requestId);

  // 路由
  app.route("/", healthRoute);
  app.route("/", createInfoRoute(downstream));
  app.route("/", createServicesRoute(downstream));
  app.route("/", createSessionsRoute(sessionStore));

  // 错误处理（最后）
  app.onError(errorHandler);

  return app;
}
```

- [ ] **Step 2: 入口**

```typescript
// src/index.ts
import { serve } from "@hono/node-server";
import { createApp } from "./app.js";
import { loadConfig } from "./config/env.js";

const config = loadConfig();
const app = createApp();

serve({ port: config.port, fetch: app.fetch }, (info) => {
  console.log(`Orchestrator-TS listening on http://0.0.0.0:${info.port}`);
  console.log(`Downstream: asr=${config.downstream.asr} tts=${config.downstream.tts} avatar=${config.downstream.avatar} llm=${config.downstream.llm}`);
});
```

- [ ] **Step 3: 安装 @hono/node-server**

```bash
cd services/orchestrator-ts && npm install @hono/node-server
```

- [ ] **Step 4: Commit**

```bash
git add services/orchestrator-ts/src/app.ts services/orchestrator-ts/src/index.ts services/orchestrator-ts/package.json
git commit -m "feat: App 装配 + 入口（Hono 全路由挂载）"
```

---

### Task 12: 启动验证

**Files:**
- Modify: `services/orchestrator-ts/.env.example`（Create）

- [ ] **Step 1: 创建 .env.example**

```env
# Orchestrator-TS 环境变量
PORT=8080
DB_PATH=:memory:
ASR_URL=http://localhost:8101
TTS_URL=http://localhost:8102
AVATAR_URL=http://localhost:8103
LLM_URL=http://localhost:8104
```

- [ ] **Step 2: 创建 .env 并启动**

```bash
cd services/orchestrator-ts
cp .env.example .env
npx tsx src/index.ts
```

Expected: 终端输出启动日志，显示监听端口和下游服务地址。

- [ ] **Step 3: 验证各接口（新终端）**

```bash
# Health
curl -s http://localhost:8080/healthz | head -c 200
# Expected: {"status":"ok","uptime_seconds":...}

# Info
curl -s http://localhost:8080/v1/info | head -c 500
# Expected: 包含 service/version/downstream

# Create session
curl -s -X POST http://localhost:8080/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"title":"测试会话"}' | head -c 500
# Expected: 201, 返回 session 对象 status=created

# List sessions
curl -s http://localhost:8080/v1/sessions | head -c 500
# Expected: 数组，包含刚创建的会话

# Update status
curl -s -X PATCH http://localhost:8080/v1/sessions/<id> \
  -H "Content-Type: application/json" \
  -d '{"status":"ready"}' | head -c 500
# Expected: status=ready

# Invalid transition (ready→created 不允许)
curl -s -X PATCH http://localhost:8080/v1/sessions/<id> \
  -H "Content-Type: application/json" \
  -d '{"status":"created"}' | head -c 500
# Expected: 400, INVALID_TRANSITION

# Services health（下游未启动，返回 healthy=false）
curl -s http://localhost:8080/v1/services/health | head -c 500
# Expected: 各服务 healthy=false
```

- [ ] **Step 4: Commit**

```bash
git add services/orchestrator-ts/.env.example
git commit -m "feat: 添加 .env.example，验证全部 API 接口通过"
```

---

### Task 13: Docker Compose 集成

**Files:**
- Modify: `compose.yaml`

- [ ] **Step 1: 更新 compose.yaml 替换 orchestrator 服务**

在 `compose.yaml` 中，将 `avastack-orchestrator` 服务替换为指向 `orchestrator-ts`：

- 将 `build: services/orchestrator-go` 改为 `build: services/orchestrator-ts`
- 环境变量名保持兼容（沿用 Go 版已有的变量名）

具体修改内容（找到 orchestrator 服务块，替换 build 和 image 字段）：

```yaml
  avastack-orchestrator:
    build: services/orchestrator-ts
    image: avastack/orchestrator-ts:latest
    container_name: avastack-orchestrator
    ports:
      - "${ORCHESTRATOR_PORT:-58080}:8080"
    environment:
      - PORT=8080
      - DB_PATH=/data/avastack.db
      - ASR_URL=http://avastack-asr:8101
      - TTS_URL=http://avastack-tts:8102
      - AVATAR_URL=http://avastack-avatar:8103
      - LLM_URL=http://avastack-llm:8104
    volumes:
      - orchestrator-data:/data
    networks:
      - avastack
    restart: unless-stopped
```

同时确保 volumes 中声明了 `orchestrator-data`（如没有则新增）。

- [ ] **Step 2: 删除临时 index.ts**

确保 `src/index.ts` 内容已是 Task 11 的最终版本（非临时 `new Response("ok")` 占位）。

- [ ] **Step 3: Commit**

```bash
git add compose.yaml
git commit -m "feat: Docker Compose 集成 orchestrator-ts，替换 orchestrator-go"
```

---

### Task 14: 文档更新

**Files:**
- Modify: `README.md`（或 `docs/architecture.md`）

- [ ] **Step 1: 更新技术栈说明**

在 README 或文档中，将调度服务描述从 "Go" 更新为 "TypeScript + Hono + SQLite"。无需新增长篇内容——几行文字说明即可。

- [ ] **Step 2: Commit**

```bash
git add README.md  # 或对应的文档文件
git commit -m "docs: 更新技术栈说明（Go → TypeScript + Hono）"
```

---

## Post-Phase Verification

全部 Task 完成后，确认以下检查点：

- [ ] `cd services/orchestrator-ts && npx tsx src/index.ts` 启动无报错
- [ ] `curl http://localhost:8080/healthz` 返回 `200`
- [ ] `POST /v1/sessions` → 创建成功，返回 `201`
- [ ] `GET /v1/sessions` → 列表包含已创建会话
- [ ] `PATCH /v1/sessions/:id { status: "ready" }` → 状态变为 `ready`
- [ ] `PATCH /v1/sessions/:id { status: "created" }` → 返回 `400 INVALID_TRANSITION`
- [ ] `GET /v1/sessions/:notfound` → 返回 `404 SESSION_NOT_FOUND`
- [ ] 响应格式与 Go 版统一信封一致（`request_id` / `status` / `data` / `meta`）
- [ ] `docker compose build avastack-orchestrator` 构建成功
- [ ] 原 Go 版 `orchestrator-go/` 代码未修改，保留对照
