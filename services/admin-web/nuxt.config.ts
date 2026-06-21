// nuxt.config.ts
export default defineNuxtConfig({
  devtools: { enabled: true },
  modules: ["@nuxtjs/tailwindcss"],
  ssr: false,

  devServer: {
    port: 4173,
  },

  runtimeConfig: {
    public: {
      orchestratorBaseUrl: process.env.ORCHESTRATOR_BASE_URL || "http://localhost:58080",
    },
  },

  compatibilityDate: "2026-06-21",
});