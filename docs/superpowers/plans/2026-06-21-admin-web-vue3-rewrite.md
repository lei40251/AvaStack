# Admin-Web Vue 3 重写实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Vue 3 + Nuxt 3 重写管理后台，替换现有 TypeScript 原生 DOM 实现，提供仪表盘、会话管理、服务监控三个页面

**Architecture:** Nuxt 3 约定式路由 → pages/ 目录即路由；composables/ 封装 API 调用与轮询逻辑；components/ 按页面拆分布局与业务组件；types/contracts.ts 直接引用 orchestrator-ts 的类型定义，消除重复维护

**Tech Stack:** Vue 3.5, Nuxt 3.13, TypeScript 5.6

**Design Doc:** `docs/superpowers/specs/2026-06-20-tech-stack-redesign-design.md` 第七节

**Background:** 当前 `services/admin-web/` 是 Vite + 原生 DOM 项目（`src/main.ts` 约 100 行）。本计划在原目录基础上重写为 Nuxt 3 项目，Docker compose 中服务名不变。

---

### Task 1: Nuxt 3 项目脚手架

**Files:**
- Create: `services/admin-web/package.json`
- Create: `services/admin-web/nuxt.config.ts`
- Create: `services/admin-web/tsconfig.json`
- Create: `services/admin-web/app.vue`
- Modify: `services/admin-web/.dockerignore`（Update）
- Delete: `services/admin-web/index.html`（Nuxt 自动生成）
- Delete: `services/admin-web/src/main.ts`（被 pages/ 取代）
- Delete: `services/admin-web/src/styles.css`（迁移到 assets/）
- Delete: `services/admin-web/src/runtime-config.js`（Nuxt 内置替代）

- [ ] **Step 1: 清空旧源码（保留 Dockerfile）**

```bash
cd services/admin-web
rm -f index.html src/main.ts src/styles.css src/runtime-config.js
```

- [ ] **Step 2: 创建 package.json**

```json
{
  "name": "@avastack/admin-web",
  "version": "0.2.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "nuxt dev --port 4173",
    "build": "nuxt build",
    "generate": "nuxt generate",
    "preview": "nuxt preview"
  },
  "dependencies": {
    "nuxt": "^3.13.0",
    "vue": "^3.5.0"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "@nuxtjs/tailwindcss": "^6.12.0"
  }
}
```

- [ ] **Step 3: 创建 nuxt.config.ts**

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  devtools: { enabled: true },
  modules: ["@nuxtjs/tailwindcss"],
  ssr: false,  // 管理后台纯 CSR，无需 SSR
  devServer: {
    port: 4173,
  },
  runtimeConfig: {
    public: {
      orchestratorBaseUrl: process.env.ORCHESTRATOR_BASE_URL || "http://localhost:58080",
    },
  },
});
```

- [ ] **Step 4: 创建 tsconfig.json**

```json
{
  "extends": "./.nuxt/tsconfig.json",
  "compilerOptions": {
    "strict": true
  }
}
```

- [ ] **Step 5: 创建 app.vue（根布局）**

```vue
<!-- app.vue —— 根布局：侧边栏 + 内容区 -->
<template>
  <div class="flex h-screen bg-gray-50">
    <AppSidebar />
    <div class="flex-1 flex flex-col overflow-hidden">
      <AppHeader />
      <main class="flex-1 overflow-y-auto p-6">
        <NuxtPage />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
// 根组件仅负责布局结构，不包含业务逻辑
</script>
```

- [ ] **Step 6: 安装依赖**

```bash
cd services/admin-web && npm install
```

- [ ] **Step 7: Commit**

```bash
git add services/admin-web/
git commit -m "scaffold: admin-web Nuxt 3 项目脚手架（Vue 3 + Tailwind）"
```

---

### Task 2: 共享类型

**Files:**
- Create: `services/admin-web/types/contracts.ts`

- [ ] **Step 1: 从 orchestrator-ts 复制合约类型**

```typescript
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
```

- [ ] **Step 2: Commit**

```bash
git add services/admin-web/types/contracts.ts
git commit -m "feat: admin-web 共享类型定义（与 orchestrator-ts 同步）"
```

---

### Task 3: 布局组件

**Files:**
- Create: `services/admin-web/components/layout/AppSidebar.vue`
- Create: `services/admin-web/components/layout/AppHeader.vue`

- [ ] **Step 1: AppSidebar.vue**

```vue
<!-- components/layout/AppSidebar.vue —— 侧边导航栏 -->
<template>
  <aside class="w-56 bg-slate-800 text-white flex flex-col shrink-0">
    <div class="h-14 flex items-center px-4 text-lg font-bold border-b border-slate-700">
      AvaStack
    </div>
    <nav class="flex-1 py-4 space-y-1">
      <NuxtLink
        v-for="item in navItems"
        :key="item.to"
        :to="item.to"
        class="flex items-center px-4 py-2.5 text-sm transition-colors rounded mx-2"
        :class="isActive(item.to)
          ? 'bg-slate-700 text-white'
          : 'text-slate-300 hover:bg-slate-700 hover:text-white'"
      >
        <span class="mr-3 text-base">{{ item.icon }}</span>
        {{ item.label }}
      </NuxtLink>
    </nav>
  </aside>
</template>

<script setup lang="ts">
const navItems = [
  { to: "/",          icon: "📊", label: "仪表盘" },
  { to: "/sessions",  icon: "💬", label: "会话管理" },
  { to: "/services",  icon: "🩺", label: "服务监控" },
];

const route = useRoute();
function isActive(to: string): boolean {
  if (to === "/") return route.path === "/";
  return route.path.startsWith(to);
}
</script>
```

- [ ] **Step 2: AppHeader.vue**

```vue
<!-- components/layout/AppHeader.vue —— 顶部栏 -->
<template>
  <header class="h-14 bg-white border-b border-gray-200 flex items-center justify-between px-6 shrink-0">
    <h1 class="text-base font-medium text-gray-700">{{ pageTitle }}</h1>
    <div class="flex items-center gap-4 text-sm text-gray-500">
      <span>🟢 系统运行中</span>
    </div>
  </header>
</template>

<script setup lang="ts">
const route = useRoute();

const pageTitle = computed(() => {
  const map: Record<string, string> = {
    "/": "仪表盘",
  };
  if (route.path.startsWith("/sessions")) return "会话管理";
  if (route.path.startsWith("/services")) return "服务监控";
  return map[route.path] ?? "AvaStack";
});
</script>
```

- [ ] **Step 3: Commit**

```bash
git add services/admin-web/components/layout/ services/admin-web/app.vue
git commit -m "feat: 布局组件（AppSidebar + AppHeader + app.vue）"
```

---

### Task 4: API 封装与轮询

**Files:**
- Create: `services/admin-web/composables/useApi.ts`
- Create: `services/admin-web/composables/usePolling.ts`

- [ ] **Step 1: useApi.ts —— 类型安全的 HTTP 客户端**

```typescript
// composables/useApi.ts
// 封装对 orchestrator-ts 的 HTTP 调用，统一解析信封

import type { ApiEnvelope } from "~/types/contracts";

const config = useRuntimeConfig();
const BASE = config.public.orchestratorBaseUrl as string;

async function request<T>(path: string, init?: RequestInit): Promise<T> {
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

// ====== 具体 API 方法 ======

import type { Session, CreateSessionRequest, UpdateSessionRequest, ServicesHealthResponse, InfoResponse } from "~/types/contracts";

export function useApi() {
  return {
    // 会话
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

    // 服务健康
    getServicesHealth: () =>
      request<ServicesHealthResponse>("/v1/services/health"),

    // 信息
    getInfo: () =>
      request<InfoResponse>("/v1/info"),
  };
}
```

- [ ] **Step 2: usePolling.ts —— 轮询 Hook**

```typescript
// composables/usePolling.ts
// 通用轮询封装，自动清理

export function usePolling<T>(
  fetcher: () => Promise<T>,
  intervalMs: number = 10000
) {
  const data = ref<T | null>(null);
  const error = ref<string | null>(null);
  const loading = ref(false);

  let timer: ReturnType<typeof setInterval> | null = null;

  async function refresh() {
    loading.value = true;
    error.value = null;
    try {
      data.value = await fetcher();
    } catch (e: any) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  function start() {
    refresh(); // 立即执行一次
    timer = setInterval(refresh, intervalMs);
  }

  function stop() {
    if (timer) { clearInterval(timer); timer = null; }
  }

  // 组件卸载时自动停止
  onUnmounted(stop);

  return { data, error, loading, refresh, start, stop };
}
```

- [ ] **Step 3: Commit**

```bash
git add services/admin-web/composables/
git commit -m "feat: API 封装（useApi）+ 轮询 Hook（usePolling）"
```

---

### Task 5: 仪表盘页面

**Files:**
- Create: `services/admin-web/pages/index.vue`
- Create: `services/admin-web/components/dashboard/StatCard.vue`

- [ ] **Step 1: StatCard.vue**

```vue
<!-- components/dashboard/StatCard.vue —— 统计卡片 -->
<template>
  <div class="bg-white rounded-lg border border-gray-200 p-5">
    <div class="text-sm text-gray-500 mb-1">{{ label }}</div>
    <div class="text-2xl font-semibold text-gray-800">
      {{ loading ? "—" : value }}
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  label: string;
  value: number | string;
  loading?: boolean;
}>();
</script>
```

- [ ] **Step 2: pages/index.vue**

```vue
<!-- pages/index.vue —— 仪表盘首页 -->
<template>
  <div>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <StatCard label="活跃会话" :value="activeCount" :loading />
      <StatCard label="健康服务" :value="healthyCount" :loading="healthLoading" />
      <StatCard label="总会话" :value="totalCount" :loading />
    </div>

    <div class="bg-white rounded-lg border border-gray-200 p-5">
      <h2 class="text-sm font-medium text-gray-600 mb-3">最近会话</h2>
      <div v-if="loading" class="text-gray-400 text-sm">加载中…</div>
      <div v-else-if="recentSessions.length === 0" class="text-gray-400 text-sm">
        暂无会话，去「会话管理」创建一个吧
      </div>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="text-left text-gray-500 border-b">
            <th class="pb-2 font-normal">标题</th>
            <th class="pb-2 font-normal">状态</th>
            <th class="pb-2 font-normal">创建时间</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in recentSessions" :key="s.id" class="border-b last:border-0">
            <td class="py-2">{{ s.title || "(无标题)" }}</td>
            <td class="py-2"><StatusBadge :status="s.status" /></td>
            <td class="py-2 text-gray-400">{{ fmtTime(s.created_at) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useApi } from "~/composables/useApi";
import { usePolling } from "~/composables/usePolling";
import type { Session } from "~/types/contracts";

const api = useApi();

// 会话数据
const { data: sessions, loading, refresh } = usePolling<Session[]>(
  () => api.getSessions(),
  10000
);

// 健康数据（独立轮询，频率更低）
const { data: health, loading: healthLoading } = usePolling(
  () => api.getServicesHealth(),
  30000
);

onMounted(() => {
  refresh();
});

const activeCount = computed(() =>
  sessions.value?.filter((s) => s.status === "active").length ?? 0
);
const totalCount = computed(() => sessions.value?.length ?? 0);
const healthyCount = computed(() =>
  health.value
    ? Object.values(health.value.services).filter((s) => s.healthy).length
    : 0
);
const recentSessions = computed(() =>
  sessions.value?.slice(-5).reverse() ?? []
);

function fmtTime(iso: string): string {
  return new Date(iso).toLocaleString("zh-CN");
}
</script>
```

- [ ] **Step 3: Commit**

```bash
git add services/admin-web/pages/index.vue services/admin-web/components/dashboard/
git commit -m "feat: 仪表盘页面（StatCard + 会话/健康摘要）"
```

---

### Task 6: 会话列表页

**Files:**
- Create: `services/admin-web/pages/sessions/index.vue`
- Create: `services/admin-web/components/sessions/SessionTable.vue`
- Create: `services/admin-web/components/sessions/StatusBadge.vue`

- [ ] **Step 1: StatusBadge.vue**

```vue
<!-- components/sessions/StatusBadge.vue —— 状态标签 -->
<template>
  <span :class="badgeClass">{{ label }}</span>
</template>

<script setup lang="ts">
import type { SessionStatus } from "~/types/contracts";

const props = defineProps<{ status: SessionStatus }>();

const map: Record<SessionStatus, { label: string; class: string }> = {
  created: { label: "已创建", class: "bg-gray-100 text-gray-700" },
  ready:   { label: "就绪",   class: "bg-blue-100 text-blue-700" },
  active:  { label: "活跃",   class: "bg-green-100 text-green-700" },
  closed:  { label: "已关闭", class: "bg-red-100 text-red-700" },
};

const { label, class: cls } = map[props.status];
const badgeClass = `inline-block px-2 py-0.5 rounded-full text-xs font-medium ${cls}`;
</script>
```

- [ ] **Step 2: SessionTable.vue**

```vue
<!-- components/sessions/SessionTable.vue —— 会话列表表格 -->
<template>
  <div class="bg-white rounded-lg border border-gray-200">
    <table class="w-full text-sm">
      <thead>
        <tr class="text-left text-gray-500 border-b bg-gray-50">
          <th class="px-4 py-3 font-normal">标题</th>
          <th class="px-4 py-3 font-normal">状态</th>
          <th class="px-4 py-3 font-normal">创建时间</th>
          <th class="px-4 py-3 font-normal">操作</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="sessions.length === 0">
          <td colspan="4" class="px-4 py-8 text-center text-gray-400">
            暂无会话
          </td>
        </tr>
        <tr
          v-for="s in sessions"
          :key="s.id"
          class="border-b last:border-0 hover:bg-gray-50"
        >
          <td class="px-4 py-3">{{ s.title || "(无标题)" }}</td>
          <td class="px-4 py-3"><StatusBadge :status="s.status" /></td>
          <td class="px-4 py-3 text-gray-400">{{ fmtTime(s.created_at) }}</td>
          <td class="px-4 py-3">
            <NuxtLink
              :to="`/sessions/${s.id}`"
              class="text-blue-600 hover:underline text-xs"
            >
              详情
            </NuxtLink>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import type { Session } from "~/types/contracts";

defineProps<{ sessions: Session[] }>();

function fmtTime(iso: string): string {
  return new Date(iso).toLocaleString("zh-CN");
}
</script>
```

- [ ] **Step 3: pages/sessions/index.vue**

```vue
<!-- pages/sessions/index.vue —— 会话列表页 -->
<template>
  <div>
    <!-- 操作栏 -->
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-base font-medium text-gray-700">
        会话列表（{{ sessions?.length ?? 0 }}）
      </h2>
      <button
        class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors"
        @click="createSession"
        :disabled="creating"
      >
        {{ creating ? "创建中…" : "+ 新建会话" }}
      </button>
    </div>

    <!-- 表格 -->
    <div v-if="loading && !sessions" class="text-gray-400 text-sm">加载中…</div>
    <SessionTable v-else :sessions="sessions ?? []" />

    <!-- 错误提示 -->
    <div v-if="error" class="mt-3 text-red-500 text-sm">⚠ {{ error }}</div>
  </div>
</template>

<script setup lang="ts">
import { useApi } from "~/composables/useApi";
import { usePolling } from "~/composables/usePolling";
import type { Session } from "~/types/contracts";

const api = useApi();
const creating = ref(false);

const { data: sessions, loading, error, refresh } = usePolling<Session[]>(
  () => api.getSessions(),
  5000
);

onMounted(() => refresh());

async function createSession() {
  creating.value = true;
  try {
    await api.createSession({ title: `会话 ${Date.now()}` });
    await refresh();
  } catch (e: any) {
    error.value = e.message;
  } finally {
    creating.value = false;
  }
}
</script>
```

- [ ] **Step 4: Commit**

```bash
git add services/admin-web/pages/sessions/index.vue services/admin-web/components/sessions/
git commit -m "feat: 会话列表页（SessionTable + StatusBadge + 新建）"
```

---

### Task 7: 会话详情页

**Files:**
- Create: `services/admin-web/pages/sessions/[id].vue`

- [ ] **Step 1: pages/sessions/[id].vue**

```vue
<!-- pages/sessions/[id].vue —— 会话详情 + 状态流转 -->
<template>
  <div v-if="pending" class="text-gray-400">加载中…</div>
  <div v-else-if="error" class="text-red-500">⚠ {{ error }}</div>
  <div v-else-if="session" class="max-w-2xl">
    <!-- 基本信息 -->
    <div class="bg-white rounded-lg border border-gray-200 p-5 mb-4">
      <h2 class="text-base font-medium text-gray-700 mb-4">会话详情</h2>
      <dl class="grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt class="text-gray-400">ID</dt>
          <dd class="text-gray-700 font-mono text-xs">{{ session.id }}</dd>
        </div>
        <div>
          <dt class="text-gray-400">状态</dt>
          <dd><StatusBadge :status="session.status" /></dd>
        </div>
        <div>
          <dt class="text-gray-400">标题</dt>
          <dd class="text-gray-700">{{ session.title || "(无标题)" }}</dd>
        </div>
        <div>
          <dt class="text-gray-400">创建时间</dt>
          <dd class="text-gray-700">{{ fmtTime(session.created_at) }}</dd>
        </div>
        <div>
          <dt class="text-gray-400">更新时间</dt>
          <dd class="text-gray-700">{{ fmtTime(session.updated_at) }}</dd>
        </div>
        <div v-if="session.closed_at">
          <dt class="text-gray-400">关闭时间</dt>
          <dd class="text-gray-700">{{ fmtTime(session.closed_at) }}</dd>
        </div>
      </dl>
    </div>

    <!-- 状态流转 -->
    <div class="bg-white rounded-lg border border-gray-200 p-5">
      <h3 class="text-sm font-medium text-gray-600 mb-3">状态操作</h3>
      <div class="flex gap-2 flex-wrap">
        <button
          v-for="action in availableActions"
          :key="action.status"
          :disabled="transitioning"
          :class="action.btnClass"
          class="px-4 py-1.5 text-sm rounded transition-colors disabled:opacity-50"
          @click="doTransition(action.status)"
        >
          {{ action.label }}
        </button>
      </div>
      <div v-if="!availableActions.length" class="text-gray-400 text-sm">
        该会话已关闭，无可用操作
      </div>
      <div v-if="transitionError" class="mt-2 text-red-500 text-sm">
        {{ transitionError }}
      </div>
    </div>

    <div class="mt-4">
      <NuxtLink to="/sessions" class="text-blue-600 hover:underline text-sm">
        ← 返回列表
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useApi } from "~/composables/useApi";
import type { Session, SessionStatus } from "~/types/contracts";

const route = useRoute();
const api = useApi();

const session = ref<Session | null>(null);
const pending = ref(true);
const error = ref<string | null>(null);
const transitioning = ref(false);
const transitionError = ref<string | null>(null);

async function fetch() {
  pending.value = true;
  error.value = null;
  try {
    session.value = await api.getSession(route.params.id as string);
  } catch (e: any) {
    error.value = e.message;
  } finally {
    pending.value = false;
  }
}

onMounted(fetch);

// 根据当前状态计算可用操作
const transitions: Record<SessionStatus, { status: SessionStatus; label: string }[]> = {
  created: [
    { status: "ready",  label: "→ 就绪" },
    { status: "closed", label: "→ 关闭" },
  ],
  ready: [
    { status: "active", label: "→ 激活" },
    { status: "closed", label: "→ 关闭" },
  ],
  active: [
    { status: "closed", label: "→ 关闭" },
  ],
  closed: [],
};

const availableActions = computed(() => {
  if (!session.value) return [];
  return (transitions[session.value.status] ?? []).map((t) => ({
    ...t,
    btnClass: t.status === "closed"
      ? "bg-red-100 text-red-700 hover:bg-red-200"
      : "bg-blue-100 text-blue-700 hover:bg-blue-200",
  }));
});

async function doTransition(status: SessionStatus) {
  if (!session.value) return;
  transitioning.value = true;
  transitionError.value = null;
  try {
    session.value = await api.updateSession(session.value.id, { status });
  } catch (e: any) {
    transitionError.value = e.message;
  } finally {
    transitioning.value = false;
  }
}

function fmtTime(iso: string): string {
  return new Date(iso).toLocaleString("zh-CN");
}
</script>
```

- [ ] **Step 2: Commit**

```bash
git add services/admin-web/pages/sessions/[id].vue
git commit -m "feat: 会话详情页（状态流转按钮 + 基本信息展示）"
```

---

### Task 8: 服务监控页

**Files:**
- Create: `services/admin-web/pages/services/index.vue`
- Create: `services/admin-web/components/services/ServiceCard.vue`
- Create: `services/admin-web/components/services/HealthIndicator.vue`

- [ ] **Step 1: HealthIndicator.vue**

```vue
<!-- components/services/HealthIndicator.vue —— 健康指示灯 -->
<template>
  <span class="inline-flex items-center gap-1.5 text-sm">
    <span
      class="w-2 h-2 rounded-full"
      :class="healthy ? 'bg-green-500' : 'bg-red-500'"
    />
    <span :class="healthy ? 'text-green-700' : 'text-red-700'">
      {{ healthy ? "健康" : "异常" }}
    </span>
  </span>
</template>

<script setup lang="ts">
defineProps<{ healthy: boolean }>();
</script>
```

- [ ] **Step 2: ServiceCard.vue**

```vue
<!-- components/services/ServiceCard.vue —— 服务健康卡片 -->
<template>
  <div class="bg-white rounded-lg border border-gray-200 p-4">
    <div class="flex items-center justify-between mb-2">
      <span class="font-medium text-gray-700 uppercase text-xs">{{ name }}</span>
      <HealthIndicator :healthy="health.healthy" />
    </div>
    <div class="text-xs text-gray-400">
      延迟：
      <span v-if="health.latency_ms !== null">{{ health.latency_ms }}ms</span>
      <span v-else>—</span>
    </div>
    <div v-if="health.error" class="mt-1 text-xs text-red-400 truncate" :title="health.error">
      {{ health.error }}
    </div>
  </div>
</template>

<script setup lang="ts">
import type { ServiceHealth } from "~/types/contracts";

defineProps<{
  name: string;
  health: ServiceHealth;
}>();
</script>
```

- [ ] **Step 3: pages/services/index.vue**

```vue
<!-- pages/services/index.vue —— 服务健康监控面板 -->
<template>
  <div>
    <h2 class="text-base font-medium text-gray-700 mb-4">服务健康监控</h2>

    <div v-if="loading && !health" class="text-gray-400 text-sm">检测中…</div>

    <div v-else-if="health" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <ServiceCard
        v-for="(svc, name) in health.services"
        :key="name"
        :name="name"
        :health="svc"
      />
    </div>

    <div v-if="error" class="mt-3 text-red-500 text-sm">⚠ {{ error }}</div>

    <p class="mt-4 text-xs text-gray-400">
      每 10 秒自动刷新 · 上次：
      {{ lastRefresh ?? "—" }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { useApi } from "~/composables/useApi";
import { usePolling } from "~/composables/usePolling";
import type { ServicesHealthResponse } from "~/types/contracts";

const api = useApi();
const lastRefresh = ref<string | null>(null);

const { data: health, loading, error } = usePolling<ServicesHealthResponse>(
  () => api.getServicesHealth(),
  10000
);

watch(health, () => {
  if (health.value) {
    lastRefresh.value = new Date().toLocaleTimeString("zh-CN");
  }
});
</script>
```

- [ ] **Step 4: Commit**

```bash
git add services/admin-web/pages/services/ services/admin-web/components/services/
git commit -m "feat: 服务监控页（ServiceCard + 健康指示灯 + 自动轮询）"
```

---

### Task 9: Dockerfile 更新

**Files:**
- Modify: `services/admin-web/Dockerfile`
- Modify: `services/admin-web/.dockerignore`

- [ ] **Step 1: 更新 Dockerfile（Nuxt 3 生产构建）**

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS run
WORKDIR /app
RUN addgroup -S avastack && adduser -S avastack -G avastack
COPY --from=build /app/.output ./.output
COPY --from=build /app/package.json ./
USER avastack
EXPOSE 4173
ENV NODE_ENV=production
CMD ["node", ".output/server/index.mjs"]
```

- [ ] **Step 2: 更新 .dockerignore**

```
node_modules
.output
dist
.env
.nuxt
*.log
```

- [ ] **Step 3: Commit**

```bash
git add services/admin-web/Dockerfile services/admin-web/.dockerignore
git commit -m "feat: 更新 Dockerfile 适配 Nuxt 3 生产构建"
```

---

### Task 10: Compose 集成与验证

**Files:**
- Modify: `compose.yaml`（检查 avastack-admin 服务）

- [ ] **Step 1: 检查 compose.yaml 中 admin-web 配置**

compose.yaml 中 `avastack-admin` 服务无需改动——构建上下文 `./services/admin-web`、端口映射 `54173:4173` 均不变，Nuxt 3 仍使用端口 4173。

- [ ] **Step 2: 本地启动验证**

```bash
cd services/admin-web
npm run dev
```

Expected: Nuxt 3 开发服务器启动在 `http://localhost:4173`，三个页面可访问。

- [ ] **Step 3: 页面验证（浏览器 / curl）**

```bash
# 仪表盘
curl -s http://localhost:4173/ | head -c 500
# Expected: HTML 页面，包含 "AvaStack" 品牌

# 会话列表
curl -s http://localhost:4173/sessions | head -c 500

# 服务监控
curl -s http://localhost:4173/services | head -c 500
```

- [ ] **Step 4: Commit**

```bash
git add compose.yaml  # 如有改动
git commit -m "feat: admin-web Nuxt 3 集成完成，本地验证通过"
```

---

## Post-Phase Verification

全部 Task 完成后，确认以下检查点：

- [ ] `cd services/admin-web && npm run dev` 启动无报错
- [ ] `http://localhost:4173` 仪表盘渲染正常
- [ ] `http://localhost:4173/sessions` 会话列表显示 orchestrator 数据
- [ ] `http://localhost:4173/sessions/:id` 会话详情 + 状态流转可用
- [ ] `http://localhost:4173/services` 服务健康面板自动轮询
- [ ] 三个页面侧边栏导航正常切换
- [ ] `docker compose build avastack-admin` 构建成功
- [ ] 原 `src/main.ts` 等旧文件已移除
