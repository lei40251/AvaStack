// types/contracts.ts
// 从 services/orchestrator-ts/src/types/contracts.ts 复制
// 后续可改为 monorepo 共享包，当前直接复制保持独立

export interface ApiEnvelope<T> {
  request_id: string;
  session_id?: string;
  status: "ok";
  data: T;
  meta: { at: string; took_ms: number };
}

export interface ApiErrorBody {
  request_id: string;
  status: "error";
  error: { code: string; message: string; detail?: unknown };
  meta: { at: string; took_ms: number };
}

export type SessionStatus = "created" | "ready" | "active" | "closed";

export interface Session {
  id: string;
  status: SessionStatus;
  title: string;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  closed_at: string | null;
}

export interface CreateSessionRequest {
  title?: string;
  metadata?: Record<string, unknown>;
}

export interface UpdateSessionRequest {
  status: "ready" | "active" | "closed";
}

export interface ServiceHealth {
  healthy: boolean;
  latency_ms: number | null;
  error?: string;
}

export interface ServicesHealthResponse {
  services: Record<string, ServiceHealth>;
}

export interface InfoResponse {
  service: string;
  version: string;
  downstream: Record<string, string>;
}
