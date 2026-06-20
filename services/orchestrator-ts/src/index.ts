// src/index.ts
// Orchestrator-TS 服务入口

import { serve } from "@hono/node-server";
import { createApp } from "./app.js";
import { loadConfig } from "./config/env.js";

const config = loadConfig();
const app = createApp();

serve({ port: config.port, fetch: app.fetch }, (info) => {
  console.log(`Orchestrator-TS listening on http://0.0.0.0:${info.port}`);
  console.log(`Downstream: asr=${config.downstream.asr} tts=${config.downstream.tts} avatar=${config.downstream.avatar} llm=${config.downstream.llm}`);
});
