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
