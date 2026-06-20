// composables/usePolling.ts
// 通用轮询封装，自动清理

export function usePolling<T>(
  fetcher: () => Promise<T>,
  intervalMs: number = 10000
) {
  const data = ref<T | null>(null);
  const error = ref<string | null>(null);
  const loading = ref(false);

  let timer: ReturnType<typeof setInterval> | null = null;

  async function refresh() {
    loading.value = true;
    error.value = null;
    try {
      data.value = await fetcher();
    } catch (e: any) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  function start() {
    refresh();
    timer = setInterval(refresh, intervalMs);
  }

  function stop() {
    if (timer) { clearInterval(timer); timer = null; }
  }

  onUnmounted(stop);

  return { data, error, loading, refresh, start, stop };
}
