// src/config/env.ts
// 根据 Go 版 internal/config/config.go 的环境变量约定改写
// 环境变量名与现有 .env.example / compose.yaml 保持兼容

export interface AppConfig {
  port: number;
  downstream: {
    asr: string;
    tts: string;
    avatar: string;
    llm: string;
  };
  dbPath: string;
}

// 读取环境变量，未设置时返回默认值（与 Go 版 env() 行为一致）
function env(key: string, fallback: string): string {
  const val = process.env[key];
  if (!val) return fallback;
  return val;
}

export function loadConfig(): AppConfig {
  return {
    port: parseInt(env("PORT", "8080"), 10),
    downstream: {
      asr:    env("ASR_BASE_URL", "http://localhost:8101"),
      tts:    env("TTS_BASE_URL", "http://localhost:8102"),
      avatar: env("AVATAR_BASE_URL", "http://localhost:8103"),
      llm:    env("LLM_BASE_URL", "http://localhost:8104"),
    },
    dbPath: env("DB_PATH", ":memory:"),
  };
}
