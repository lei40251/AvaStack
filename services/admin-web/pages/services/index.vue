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
      每 10 秒自动刷新 · 上次：{{ lastRefresh ?? "—" }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { useApi } from "~/composables/useApi";
import { usePolling } from "~/composables/usePolling";
import type { ServicesHealthResponse } from "~/types/contracts";

const api = useApi();
const lastRefresh = ref<string | null>(null);

const { data: health, loading, error, start } = usePolling<ServicesHealthResponse>(
  () => api.getServicesHealth(),
  10000
);

onMounted(() => {
  console.log("[services] onMounted, calling start()");
  start();
});

watch(health, () => {
  if (health.value) {
    lastRefresh.value = new Date().toLocaleTimeString("zh-CN");
  }
});
</script>
