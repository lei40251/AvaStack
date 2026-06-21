<!-- components/sessions/SessionTable.vue —— 会话列表表格 -->
<template>
  <div class="bg-white rounded-lg border border-gray-200">
    <table class="w-full text-sm">
      <thead>
        <tr class="text-left text-gray-500 border-b bg-gray-50">
          <th class="px-4 py-3 font-normal">标题</th>
          <th class="px-4 py-3 font-normal">状态</th>
          <th class="px-4 py-3 font-normal">创建时间</th>
          <th class="px-4 py-3 font-normal">操作</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="sessions.length === 0">
          <td colspan="4" class="px-4 py-8 text-center text-gray-400">暂无会话</td>
        </tr>
        <tr
          v-for="s in sessions"
          :key="s.id"
          class="border-b last:border-0 hover:bg-gray-50"
        >
          <td class="px-4 py-3">{{ s.title || "(无标题)" }}</td>
          <td class="px-4 py-3"><StatusBadge :status="s.status" /></td>
          <td class="px-4 py-3 text-gray-400">{{ fmtTime(s.created_at) }}</td>
          <td class="px-4 py-3">
            <NuxtLink
              :to="`/sessions/${s.id}`"
              class="text-blue-600 hover:underline text-xs"
            >详情</NuxtLink>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import type { Session } from "~/types/contracts";

defineProps<{ sessions: Session[] }>();

function fmtTime(iso: string): string {
  return new Date(iso).toLocaleString("zh-CN");
}
</script>
