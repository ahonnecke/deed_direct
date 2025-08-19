// supabase/functions/payments/stripeWebhook/index.ts
// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts"

export default serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 })

  // TODO: verify Stripe signature using your secret
  const event = await req.json()
  // switch (event.type) { ... }
  return new Response(JSON.stringify({ received: true }), {
    headers: { "content-type": "application/json" },
  })
})
