<!-- components/layout/AppSidebar.vue —— 侧边导航栏 -->
<template>
  <aside class="w-56 bg-slate-800 text-white flex flex-col shrink-0">
    <div class="h-14 flex items-center px-4 text-lg font-bold border-b border-slate-700">
      AvaStack
    </div>
    <nav class="flex-1 py-4 space-y-1">
      <NuxtLink
        v-for="item in navItems"
        :key="item.to"
        :to="item.to"
        class="flex items-center px-4 py-2.5 text-sm transition-colors rounded mx-2"
        :class="isActive(item.to)
          ? 'bg-slate-700 text-white'
          : 'text-slate-300 hover:bg-slate-700 hover:text-white'"
      >
        <span class="mr-3 text-base">{{ item.icon }}</span>
        {{ item.label }}
      </NuxtLink>
    </nav>
  </aside>
</template>

<script setup lang="ts">
const navItems = [
  { to: "/",          icon: "📊", label: "仪表盘" },
  { to: "/sessions",  icon: "💬", label: "会话管理" },
  { to: "/services",  icon: "🩺", label: "服务监控" },
];

const route = useRoute();
function isActive(to: string): boolean {
  if (to === "/") return route.path === "/";
  return route.path.startsWith(to);
}
</script>
