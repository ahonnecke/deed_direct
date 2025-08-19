// apps/mobile/app.config.ts
import 'dotenv/config'

export default {
  expo: {
    name: "supa-mobile",
    slug: "supa-mobile",
    scheme: "supa-mobile",
    experiments: { typedRoutes: true },
    extra: {
      expoPublic: {
        SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
        SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
      }
    }
  }
}
