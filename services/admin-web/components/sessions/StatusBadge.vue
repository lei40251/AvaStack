<!-- components/sessions/StatusBadge.vue —— 状态标签 -->
<template>
  <span :class="badgeClass">{{ label }}</span>
</template>

<script setup lang="ts">
import type { SessionStatus } from "~/types/contracts";

const props = defineProps<{ status: SessionStatus }>();

const map: Record<SessionStatus, { label: string; class: string }> = {
  created: { label: "已创建", class: "bg-gray-100 text-gray-700" },
  ready:   { label: "就绪",   class: "bg-blue-100 text-blue-700" },
  active:  { label: "活跃",   class: "bg-green-100 text-green-700" },
  closed:  { label: "已关闭", class: "bg-red-100 text-red-700" },
};

const { label, class: cls } = map[props.status];
const badgeClass = `inline-block px-2 py-0.5 rounded-full text-xs font-medium ${cls}`;
</script>
