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
