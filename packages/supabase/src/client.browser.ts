import { createBrowserClient } from "@supabase/ssr";

export function createPublicClient() {
  // Get environment variables directly from Next.js
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  
  // Log configuration for debugging
  console.log('Supabase client configuration:', { 
    url_available: Boolean(url),
    key_available: Boolean(key),
    env_mode: process.env.NODE_ENV
  });
  
  // Check if URL and key are available
  if (!url || !key) {
    throw new Error('Supabase URL and API key are required! Check your environment variables.');
  }
  
  // Create the client with the actual values
  return createBrowserClient(url, key);
}
