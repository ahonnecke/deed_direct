// packages/supabase/src/client.ts
import { createBrowserClient, createServerClient } from '@supabase/ssr'

export function createPublicClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  
  if (!url) throw new Error('NEXT_PUBLIC_SUPABASE_URL is missing in environment variables')
  if (!key) throw new Error('NEXT_PUBLIC_SUPABASE_ANON_KEY is missing in environment variables')
  
  return createBrowserClient(url, key)
}

export function createSSRClient(cookies: {
  get: (name: string) => string | undefined
  set?: (name: string, value: string, options?: any) => void
  remove?: (name: string, options?: any) => void
}) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY
  
  if (!url) throw new Error('NEXT_PUBLIC_SUPABASE_URL or SUPABASE_URL is missing in environment variables')
  if (!key) throw new Error('NEXT_PUBLIC_SUPABASE_ANON_KEY or SUPABASE_ANON_KEY is missing in environment variables')
  
  return createServerClient(url, key, { cookies })
}
