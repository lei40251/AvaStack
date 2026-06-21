<!-- app.vue —— 根布局：侧边栏 + 内容区 -->
<template>
  <div class="flex h-screen bg-gray-50">
    <TheSidebar />
    <div class="flex-1 flex flex-col overflow-hidden">
      <TheHeader />
      <main class="flex-1 overflow-y-auto p-6">
        <NuxtPage />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
// TheSidebar / TheHeader 由 Nuxt 自动导入（避免 App* 前缀与根组件冲突）
</script>
