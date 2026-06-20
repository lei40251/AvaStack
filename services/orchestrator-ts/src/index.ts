import { serve } from "@hono/node-server";

serve({ port: 8080, fetch: (req) => new Response("ok") });
console.log("Orchestrator-TS listening on :8080");
