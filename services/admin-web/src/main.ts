import "./styles.css";

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Missing #app container");
}

const ORCHESTRATOR_BASE_URL =
  (globalThis as typeof globalThis & { __ORCHESTRATOR_BASE_URL__?: string }).__ORCHESTRATOR_BASE_URL__ ??
  "http://localhost:58080";

type ServiceHealth = {
  name: string;
  healthy: boolean;
  status_code?: number;
  error?: string;
};

type SessionItem = {
  session_id: string;
  status: string;
  mode: string;
  avatar_id: string;
};

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

async function fetchJSON<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}`);
  }
  return (await response.json()) as T;
}

function renderShell(): void {
  app.innerHTML = `
    <main class="layout">
      <section class="hero">
        <p class="eyebrow">元述 AvaStack</p>
        <h1>私有化部署控制平面</h1>
        <p class="intro">
          当前页面直接读取编排层接口，展示服务健康和会话状态，作为后续运维面板的起点。
        </p>
      </section>
      <section class="grid">
        <article class="card">
          <h2>服务健康</h2>
          <div id="service-health">加载中...</div>
        </article>
        <article class="card">
          <h2>当前会话</h2>
          <div id="session-list">加载中...</div>
        </article>
        <article class="card">
          <h2>系统说明</h2>
          <p>Go 编排层负责控制面，Python 服务负责模型边界，LiveKit 和 SRS 负责媒体基础设施。</p>
        </article>
      </section>
    </main>
  `;
}

function renderHealth(items: ServiceHealth[]): void {
  const container = document.querySelector<HTMLDivElement>("#service-health");
  if (!container) return;
  container.innerHTML = items
    .map((item) => {
      const state = item.healthy ? "正常" : "异常";
      const extra = item.error ? ` / ${escapeHtml(item.error)}` : item.status_code ? ` / ${item.status_code}` : "";
      return `<p><strong>${escapeHtml(item.name)}</strong>：${state}${extra}</p>`;
    })
    .join("");
}

function renderSessions(items: SessionItem[]): void {
  const container = document.querySelector<HTMLDivElement>("#session-list");
  if (!container) return;
  if (items.length === 0) {
    container.innerHTML = "<p>当前还没有会话。</p>";
    return;
  }
  container.innerHTML = items
    .map(
      (item) =>
        `<p><strong>${escapeHtml(item.session_id)}</strong><br />状态：${escapeHtml(item.status)} / 模式：${escapeHtml(item.mode)} / Avatar：${escapeHtml(item.avatar_id)}</p>`,
    )
    .join("");
}

async function bootstrap(): Promise<void> {
  renderShell();

  try {
    const health = await fetchJSON<{ data: { services: ServiceHealth[] } }>(
      `${ORCHESTRATOR_BASE_URL}/v1/services/health`,
    );
    renderHealth(health.data.services);
  } catch (error) {
    renderHealth([
      {
        name: "orchestrator",
        healthy: false,
        error: error instanceof Error ? error.message : "unknown error",
      },
    ]);
  }

  try {
    const sessions = await fetchJSON<{ data: { items: SessionItem[] } }>(
      `${ORCHESTRATOR_BASE_URL}/v1/sessions`,
    );
    renderSessions(sessions.data.items);
  } catch (error) {
    renderSessions([]);
    const container = document.querySelector<HTMLDivElement>("#session-list");
    if (container) {
      const message = error instanceof Error ? error.message : "unknown error";
      container.innerHTML = `<p>读取会话失败：${escapeHtml(message)}</p>`;
    }
  }
}

void bootstrap();
