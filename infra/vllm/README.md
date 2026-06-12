# vLLM 说明

计划中的部署目标：

- 自托管 Qwen
- 暴露 OpenAI 兼容接口
- 与编排层独立扩缩容

建议的下一步：

1. 单独部署一个 `vllm` 服务
2. 通过 `VLLM_BASE_URL` 让 `services/model-llm-python` 指向它
3. prompt 归一化逻辑放在 Python LLM 网关里，不放在编排层里
