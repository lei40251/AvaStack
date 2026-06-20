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
