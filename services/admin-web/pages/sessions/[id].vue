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
