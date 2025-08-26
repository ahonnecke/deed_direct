# Supabase + Expo Accelerator — Updated Plan (Web-first, Docker-ready)

## What’s working now (baseline)
- **Monorepo** (pnpm workspaces + Turborepo) with:
  - `apps/web` — Next.js 14 (App Router)  
  - `apps/mobile` — Expo Router (stubbed; not containerized yet)
  - `packages/*` — `ui`, `shared`, `supabase`
- **Web app builds & runs in Docker**  
  - `next.config.mjs` uses **no Tamagui Next plugin**; `output: 'standalone'`.  
  - **Route guard** lives under `/app` (middleware protecting `/app/:path*`).  
  - `docker-compose.yml` runs `web` on port **3000**.  
- **Tamagui** is present in packages but **not extracted** on web (plugin disabled to keep Docker build clean).

> Rationale: We prioritized a deterministic Docker build. Tamagui’s Next plugin can be reintroduced later with a known-good setup, without blocking web deploy.

---

## Adjusted tech choices (only where necessary)
- **Web UI**: Tamagui components remain usable (transpiled), but **no plugin/extraction** during web builds—for now.
- **Next.js output**: `standalone` (aligns with Dockerfile runner stage).
- **Routing**: Public `/`, protected `/app` (matches middleware config).
- **Docker**: Multi-stage build (builder → runner) shipping `.next/standalone`.

Everything else from the original plan stays intact (Supabase, TypeScript, Zod, TanStack Query, Sentry/PostHog opt-in, CI, etc.).

---

## Updated roadmap (phased, web-first)

### Phase 0 — Done
- Monorepo skeleton, pnpm workspaces, Turbo  
- Next.js app compiles under Docker (`output: 'standalone'`)  
- Route guard under `/app`  
- Compose service for web

### Phase 1 — Supabase wiring (Web)
1. Create a **Supabase project (dev)**.  
2. Apply **baseline SQL** (profiles/orgs/memberships + RLS).  
3. Add envs to `.env` (compose reads this):  
   - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`  
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY` (for SSR if needed)  
4. Wire **auth (magic link)** on web: simple sign-in page → session → redirect to `/app`.  
5. Validate RLS by fetching `profiles` as the signed-in user.

### Phase 2 — First feature (Profile) shared
1. Shared Zod schema + types in `packages/shared`.  
2. Web pages: `/app/profile` view + edit (TanStack Query + Supabase).  
3. Minimal mobile screen (not containerized yet) to keep parity.

### Phase 3 — CI + images
1. GitHub Actions: typecheck, test, **`docker build`** for `web`.  
2. Optionally push image to a registry (tag from git SHA).  
3. Keep Vercel on the table if you want non-Docker web deploys later.

### Phase 4 — Database enhancements
- Add `updated_at` triggers, `profiles.preferences` JSONB, and indexes.
- **Notifications system** with Supabase realtime subscriptions.
- **Feature flags** table for toggling features.
- **Webhooks system** for external service integration.
- **User feedback** collection mechanism.

### Phase 5 — Auth hardening
- Add password auth, rate-limits, refresh token rotation.
- **Admin dashboard** for user management and system monitoring.
- **Stripe integration** for subscription/payment management.

### Phase 6 — Mobile pass
- Offline strategy, deep links, biometrics, push (Expo).
- **Multi-language support** with i18n framework.
- **Theme system** with light/dark mode support.

### Phase 7 — Performance
- Suspense boundaries, image optimization, React Query prefetch.
- **PWA setup** for better mobile web experience.
- **Analytics integration** with privacy controls.

### Phase 8 — Testing
- **Playwright** E2E testing for web, component tests for shared UI, API mocks, test data generators.

---

## Concrete next steps (do these in order)

1. **Set Supabase env vars** in `.env` (compose reads them):
   - `NEXT_PUBLIC_SUPABASE_URL=...`  
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY=...`  
   - `SUPABASE_URL=...`  
   - `SUPABASE_ANON_KEY=...`
2. **Run DB migrations** in Supabase SQL editor using the plan’s baseline SQL (Profiles/Orgs/Memberships + RLS).  
3. **Implement web auth UI**:
   - `/sign-in` page with “email magic link”.  
   - On success, redirect to `/app`.  
   - In `/app/layout` or a top-level client provider, initialize Supabase browser client and query `auth.getSession()` on mount.
4. **Protect server routes**:
   - Keep **`middleware.ts`** checking session cookies for `/app/:path*` (already present).  
   - In server components under `/app`, call your SSR client with `cookies` to read user/session.
5. **Add `/app/profile` feature**:
   - Query `profiles` by `auth.uid()`; render a form with Zod validation; update via Supabase.
6. **CI (GitHub Actions)**:
   - Add a job that runs: `pnpm install`, `pnpm typecheck`, `pnpm test`, `docker build -t supa-accelerator/web .`
7. **Registry (optional)**:
   - Tag & push image (`supa-accelerator/web:<sha>`), then run it anywhere with `docker run -p 3000:3000 ...`.

---

## Re-introducing Tamagui’s Next plugin (later, safely)
When you want extraction/optimizations:
1. Ensure `@tamagui/next-plugin` is in **`apps/web/devDependencies`**.  
2. Use **ESM config** with **named import**:
   ```js
   // apps/web/next.config.mjs
   import { withTamagui } from '@tamagui/next-plugin'
   const withPlugins = withTamagui({
     config: '../../packages/ui/tamagui.config.ts',
     components: ['@supa/ui'],
     disableExtract: process.env.NODE_ENV === 'development',
   })
   export default withPlugins({ output: 'standalone', transpilePackages: ['react-native-web','tamagui','@tamagui/*','@supa/ui','@supa/shared','@supa/supabase'] })
   ```
3. Keep `output: 'standalone'` to match the Dockerfile.
4. If build errors mention Edge runtime, split Supabase clients:
   - `client.browser.ts` (createBrowserClient) for client components
   - `client.ssr.ts` (createServerClient) for middleware/server  
   Then import the exact one needed to avoid bundling browser code into Edge.

*(These are future steps; no action required now.)*

---

## Definition of Done (current milestone)
- ✅ Web app builds in Docker with `output: 'standalone'`.  
- ✅ `/` public, `/app` protected via middleware.  
- ⬜ Supabase envs configured in `.env`.  
- ⬜ Auth (magic link) working end-to-end on web.  
- ⬜ `/app/profile` working against RLS.  
- ⬜ CI building Docker image.

### Future Milestones
- ⬜ Notifications system with Supabase realtime.
- ⬜ Theme system with light/dark mode.
- ⬜ Feature flags implementation.
- ⬜ Webhooks system for integrations.
- ⬜ Playwright E2E testing setup.
- ⬜ Analytics with privacy controls.
- ⬜ Stripe subscription management.
- ⬜ Multi-language support (i18n).
- ⬜ User feedback collection system.
- ⬜ Admin dashboard.
- ⬜ PWA configuration.

---

## Risks / gotchas (with remedies)
- **Edge runtime warnings** from Supabase packages → use SSR/browser client split later.
- **Tamagui plugin build errors** → keep it disabled until you want extraction; current setup works without it.
- **pnpm version drift** → pin via `packageManager` in root `package.json` and/or `corepack use pnpm@9`.

---

## Feature Implementation Details

### Notifications System
```sql
-- Add to migrations/0001_base.sql
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  read boolean not null default false,
  data jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_user_id on public.notifications (user_id);
create index if not exists idx_notifications_read on public.notifications (read);
```

### Theme System
```typescript
// packages/shared/src/types/user.ts
export interface UserPreferences {
  theme: 'light' | 'dark' | 'system';
  // Add other preference options here
}
```

### Feature Flags
```sql
-- Add to migrations
create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Webhooks System
```sql
-- Add to migrations
create table if not exists public.webhooks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.orgs(id) on delete cascade,
  url text not null,
  events text[] not null,
  secret text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Playwright Testing
```bash
# Install Playwright in web app
pnpm --filter web add -D @playwright/test

# Generate config
pnpm --filter web exec -- npx playwright install
pnpm --filter web exec -- npx playwright init
```

### Analytics Integration
```typescript
// packages/shared/src/analytics/index.ts
export const trackEvent = (eventName: string, properties?: Record<string, any>) => {
  // Integration with your preferred analytics provider
  // With user preference check for privacy
};
```

### Stripe Integration
```sql
-- Add to migrations
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('active','canceled','past_due','trialing')),
  plan_id text not null,
  current_period_end timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### Multi-language Support
```typescript
// packages/shared/src/i18n/index.ts
export const translations = {
  en: { /* English strings */ },
  es: { /* Spanish strings */ },
  // Add more languages as needed
};
```

### User Feedback System
```sql
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  type text not null check (type in ('bug','feature','general')),
  message text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
```

### Admin Dashboard
```typescript
// apps/web/app/admin/page.tsx
// With proper RLS policies in Supabase for admin-only access
```

### PWA Setup
```typescript
// Add to apps/web/next.config.mjs
// PWA configuration with next-pwa
```
