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
