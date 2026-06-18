// AvaStack 运行时配置注入文件。
// 在 index.html 中先于 main.ts 加载，用于在部署时覆盖编排层地址。
// 可在 Dockerfile 或启动脚本中通过 sed / 环境变量替换等方式修改此值。
window.__ORCHESTRATOR_BASE_URL__ = "http://localhost:58080";
