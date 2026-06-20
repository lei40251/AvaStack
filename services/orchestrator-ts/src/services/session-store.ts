// src/services/session-store.ts
// 会话持久化：基于 Drizzle ORM 操作 SQLite

import { eq } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { getDb, sessions } from "./db.js";
import type { Session, SessionStatus } from "../types/contracts.js";
import { applyTransition } from "../state/state-machine.js";

// ISessionStore 接口：方便将来替换存储后端（PostgreSQL 等）
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
