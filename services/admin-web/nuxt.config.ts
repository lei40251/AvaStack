// nuxt.config.ts
export default defineNuxtConfig({
  devtools: { enabled: false },
  devServer: { port: 4173 },
  runtimeConfig: {
    public: {
      orchestratorBaseUrl: process.env.ORCHESTRATOR_BASE_URL || "http://localhost:58080",
    },
  },
});
