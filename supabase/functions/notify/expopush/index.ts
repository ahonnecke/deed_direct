// supabase/functions/notify/expopush/index.ts
// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts"

type PushReq = { token: string; title: string; body?: string; data?: Record<string, any> }

export default serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 })
  const payload = (await req.json()) as PushReq

  if (!payload?.token || !payload?.title) {
    return new Response(JSON.stringify({ error: "token and title required" }), { status: 400 })
  }

  // Call Expo push API (you'll add your auth headers/logic):
  // await fetch("https://exp.host/--/api/v2/push/send", { ... })

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" },
  })
})
