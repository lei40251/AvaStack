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
