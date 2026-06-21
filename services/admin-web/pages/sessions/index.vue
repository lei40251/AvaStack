<!-- pages/sessions/index.vue —— 会话列表页 -->
<template>
  <div>
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-base font-medium text-gray-700">
        会话列表（{{ sessions?.length ?? 0 }}）
      </h2>
      <button
        class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors disabled:opacity-50"
        @click="createSession"
        :disabled="creating"
      >
        {{ creating ? "创建中…" : "+ 新建会话" }}
      </button>
    </div>

    <div v-if="loading && !sessions" class="text-gray-400 text-sm">加载中…</div>
    <SessionTable v-else :sessions="sessions ?? []" />

    <div v-if="error" class="mt-3 text-red-500 text-sm">⚠ {{ error }}</div>
  </div>
</template>

<script setup lang="ts">
import { useApi } from "~/composables/useApi";
import { usePolling } from "~/composables/usePolling";
import type { Session } from "~/types/contracts";

const api = useApi();
const creating = ref(false);

const { data: sessions, loading, error, start, refresh } = usePolling<Session[]>(
  () => api.getSessions(),
  5000
);

onMounted(() => start());

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
