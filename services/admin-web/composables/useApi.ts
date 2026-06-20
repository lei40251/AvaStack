// composables/useApi.ts
// 封装对 orchestrator-ts 的 HTTP 调用，统一解析信封

import type { ApiEnvelope, Session, CreateSessionRequest, UpdateSessionRequest, ServicesHealthResponse, InfoResponse } from "~/types/contracts";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const config = useRuntimeConfig();
  const BASE = config.public.orchestratorBaseUrl as string;

  const resp = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json", ...init?.headers },
    ...init,
  });

  const body = await resp.json();

  if (!resp.ok || body.status === "error") {
    const msg = body?.error?.message ?? `HTTP ${resp.status}`;
    throw new Error(msg);
  }

  return (body as ApiEnvelope<T>).data;
}

export function useApi() {
  return {
    getSessions: () =>
      request<Session[]>("/v1/sessions"),

    getSession: (id: string) =>
      request<Session>(`/v1/sessions/${id}`),

    createSession: (body: CreateSessionRequest) =>
      request<Session>("/v1/sessions", {
        method: "POST",
        body: JSON.stringify(body),
      }),

    updateSession: (id: string, body: UpdateSessionRequest) =>
      request<Session>(`/v1/sessions/${id}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      }),

    getServicesHealth: () =>
      request<ServicesHealthResponse>("/v1/services/health"),

    getInfo: () =>
      request<InfoResponse>("/v1/info"),
  };
}
