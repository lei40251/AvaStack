// src/services/downstream.ts
// 下游服务注册器：跟踪 4 个 AI 模型服务并聚合健康检查

import type { AppConfig } from "../config/env.js";
import type { ServiceHealth, ServicesHealthResponse } from "../types/contracts.js";

const HEALTH_TIMEOUT_MS = 5000;

interface DownstreamDef {
  name: string;
  url: string;
}

export class DownstreamRegistry {
  private services: DownstreamDef[];

  constructor(config: AppConfig) {
    this.services = [
      { name: "asr",    url: config.downstream.asr },
      { name: "tts",    url: config.downstream.tts },
      { name: "avatar", url: config.downstream.avatar },
      { name: "llm",    url: config.downstream.llm },
    ];
  }

  // 聚合所有下游服务健康状态
  async checkAll(): Promise<ServicesHealthResponse> {
    const results = await Promise.all(
      this.services.map((svc) => this.checkOne(svc))
    );

    const services: Record<string, ServiceHealth> = {};
    for (const r of results) {
      services[r.name] = r.health;
    }
    return { services };
  }

  // 检查单个下游服务的 /healthz 端点
  private async checkOne(
    svc: DownstreamDef
  ): Promise<{ name: string; health: ServiceHealth }> {
    const start = Date.now();
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS);

      const resp = await fetch(`${svc.url}/healthz`, {
        signal: controller.signal,
      });
      clearTimeout(timer);

      const latency_ms = Date.now() - start;

      return {
        name: svc.name,
        health: {
          healthy: resp.ok,
          latency_ms,
        },
      };
    } catch (err: any) {
      return {
        name: svc.name,
        health: {
          healthy: false,
          latency_ms: null,
          error: err.message,
        },
      };
    }
  }

  // 供 /v1/info 接口使用，返回下游地址映射
  getDownstreamUrls(): Record<string, string> {
    const urls: Record<string, string> = {};
    for (const svc of this.services) {
      urls[svc.name] = svc.url;
    }
    return urls;
  }
}
