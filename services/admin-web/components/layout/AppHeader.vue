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
  if (route.path.startsWith("/sessions")) return "会话管理";
  if (route.path.startsWith("/services")) return "服务监控";
  return "仪表盘";
});
</script>
