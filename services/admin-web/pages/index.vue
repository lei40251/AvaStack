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

const { data: sessions, loading, start: startSessions } = usePolling<Session[]>(
  () => api.getSessions(),
  10000
);

const { data: health, loading: healthLoading, start: startHealth } = usePolling(
  () => api.getServicesHealth(),
  30000
);

onMounted(() => {
  startSessions();
  startHealth();
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
