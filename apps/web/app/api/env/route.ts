import { NextResponse } from 'next/server';

export async function GET() {
  // Collect environment variables
  const envVars = {
    // Supabase variables
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL || 'Not set',
    SUPABASE_URL: process.env.SUPABASE_URL || 'Not set',
    
    // Don't expose sensitive keys, just show if they're set
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? 'Set (redacted)' : 'Not set',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY ? 'Set (redacted)' : 'Not set',
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY ? 'Set (redacted)' : 'Not set',
    
    // Node environment
    NODE_ENV: process.env.NODE_ENV || 'Not set',
    NEXT_RUNTIME: process.env.NEXT_RUNTIME || 'Not set',
  };

  // Return environment variables as JSON
  return NextResponse.json({
    message: 'Server-side environment variables',
    timestamp: new Date().toISOString(),
    environment: envVars,
  });
}
