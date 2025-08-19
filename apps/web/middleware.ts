// apps/web/middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { createSSRClient } from '@supa/supabase/src/client'

export async function middleware(req: NextRequest) {
  if (!req.nextUrl.pathname.startsWith('/app')) return NextResponse.next()

  const res = NextResponse.next()
  const cookies = {
    get: (k: string) => req.cookies.get(k)?.value,
    set: (k: string, v: string, opts?: any) => res.cookies.set(k, v, opts),
    remove: (k: string, opts?: any) => res.cookies.delete(k),
  }

  const supabase = createSSRClient(cookies)
  const { data } = await supabase.auth.getSession()
  if (!data.session) {
    const url = new URL('/', req.url)
    url.searchParams.set('redirectedFrom', req.nextUrl.pathname)
    return NextResponse.redirect(url)
  }
  return res
}

export const config = {
  matcher: ['/app/:path*'],
}
