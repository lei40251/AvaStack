declare module 'hono' {
  export class Hono<
    E = any,
    S = any,
    BasePath extends string = '/'
  > {
    constructor(options?: any)
    get(path: string, ...handlers: any[]): this
    post(path: string, ...handlers: any[]): this
    put(path: string, ...handlers: any[]): this
    delete(path: string, ...handlers: any[]): this
    patch(path: string, ...handlers: any[]): this
    options(path: string, ...handlers: any[]): this
    all(path: string, ...handlers: any[]): this
    route(path: string, app: any): this
    use(path: string, ...middleware: any[]): this
    onError(handler: (err: Error, c: any) => Response | Promise<Response>): this
    notFound(handler: (c: any) => Response | Promise<Response>): this
    fetch(request: Request, env?: any, executionCtx?: any): Response | Promise<Response>
    request(input: Request | string | URL, requestInit?: RequestInit, env?: any, executionCtx?: any): Response | Promise<Response>
    fire(): void
  }
  export type Env = any
  export type ErrorHandler = (err: Error, c: any) => Response | Promise<Response>
  export type MiddlewareHandler = (c: any, next: any) => any
  export type Context = any
  export type ContextVariableMap = any
  export type Schema = any
  export type Input = any
  export type ValidationTargets = any
  export type TypedResponse<T = any> = Response
  export type HonoRequest = any
  export type Next = any
}
