// src/services/db.ts
// SQLite 数据库连接与 Schema 定义（Drizzle ORM + better-sqlite3）

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
    // 自动建表（开发期，生产期改用 drizzle-kit migrate）
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
