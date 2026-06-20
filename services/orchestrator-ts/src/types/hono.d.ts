// types/hono.d.ts
// 扩展 Hono 的 ContextVariableMap，声明自定义上下文变量

declare module "hono" {
  interface ContextVariableMap {
    requestId: string;
  }
}
