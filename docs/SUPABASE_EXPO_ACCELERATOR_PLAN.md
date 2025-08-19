# Supabase + Expo Accelerator — Implementation Plan

**Goal:** A reusable, low-cost template that ships **mobile (Expo Managed)** and **web (Next.js)** from one monorepo, shares UI/components, and plugs straight into **Supabase** (auth, database, storage, realtime). Opinionated enough to move fast, modular enough to pivot.

---

## 1) Guiding Principles

- **Cheap & simple by default**: free/low-cost tiers only; optional upgrades later.
- **One repo, two apps, shared UI**: native + web without duplicating code.
- **Type-safe & linted**: strict TypeScript, Biome for lint/format, Zod for validation.
- **Feature-modular**: drop-in `features/*` with screens, hooks, and server pieces.
- **Cloud primitives**: Supabase for auth/DB/storage/realtime; no custom servers to start.
- **Fast iteration**: generators, scripts, and minimal boilerplate to ship ideas quickly.

---

## 2) Tech Stack (Chosen Defaults)

- **Client apps**
  - **Expo (Managed Workflow)** for iOS/Android using **Expo Router**.
  - **Next.js** for web (CSR/SSR/ISR as needed).
  - **Tamagui** UI kit to share components/styles across native & web.
- **Backend / BaaS**
  - **Supabase**: Postgres + Auth + Storage + Realtime + Policies (RLS).
- **Language / Tooling**
  - **TypeScript** everywhere.
  - **pnpm** workspaces + **Turborepo** for task orchestration.
  - **Biome** for lint & format (fast; no Prettier + ESLint juggling).
  - **Zod** for runtime schema validation.
  - **TanStack Query** for data-fetching/caching on both apps.
- **Observability**
  - **Sentry** (free tier) for crash/error monitoring.
  - **PostHog** (free) for product analytics (opt-in per project).
- **Testing**
  - **Vitest** + **Testing Library** (web).
  - **Jest** (React Native, unit-level) + **Detox** optional for e2e later.
- **CI/CD**
  - **GitHub Actions** (typecheck, lint, tests).
  - **Vercel** for web deploys.
  - **Expo EAS** for build & updates (dev/prod profiles; OTA updates).

---

## 3) Monorepo Layout

```
apps/
  mobile/          # Expo app (Managed)
  web/             # Next.js app
packages/
  ui/              # Tamagui components, theming, icons
  shared/          # shared utils, hooks, types, constants
  supabase/        # client factory, helpers, RLS-friendly hooks
  config/          # tsconfig, biome config, eslint (if needed), jest presets
tools/
  scripts/         # scaffolding & codegen (e.g., create-feature.ts)
```

> **Why Tamagui?** Shared styling/components with great RN + web parity and tree-shaking.

---

## 4) Environment & Configuration

- **Supabase vars**
  - Public (safe for client): `SUPABASE_URL`, `SUPABASE_ANON_KEY`
  - Service (server-only; used in Next API routes / scripts): `SUPABASE_SERVICE_ROLE_KEY`
- **Files**
  - `apps/mobile/.env` → use **Expo** `app.config.(ts|js)` to expose via `EXPO_PUBLIC_*`
  - `apps/web/.env.local` for Next.js (client & server handled by Next conventions)
  - `packages/supabase/` exports a `createClient(isServer?: boolean)` helper that picks the right key automatically and protects service keys from client import.

**Example:**

```ts
// packages/supabase/src/client.ts
import { createBrowserClient, createServerClient } from '@supabase/ssr';

export function createClient(server = false, cookies?: { get: (k: string)=>string | undefined, set?: any, remove?: any }) {
  if (server) {
    return createServerClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!, // server-only
      { cookies }
    );
  }
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.EXPO_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!
  );
}
```

---

## 5) Supabase: Schema & Auth

### 5.1 Tables (baseline)
- `profiles` — 1:1 with `auth.users`
  - `id uuid primary key` (equals `auth.users.id`)
  - `full_name text`, `avatar_url text`, `onboarded boolean default false`
  - `created_at timestamptz default now()`
- `orgs` — organizations/projects/teams
  - `id uuid primary key default gen_random_uuid()`
  - `name text not null`, `owner uuid references auth.users(id)`
- `memberships` — user ↔ org role mapping
  - `org_id uuid references orgs(id) on delete cascade`
  - `user_id uuid references auth.users(id) on delete cascade`
  - `role text check (role in ('owner','admin','member')) not null default 'member'`
  - `primary key (org_id, user_id)`

### 5.2 RLS Policies (sketch)
- `profiles`: user can `select/update` **own row**: `auth.uid() = id`
- `orgs`: members can `select`; owners/admins can `update/delete`
- `memberships`: members can `select` where `user_id = auth.uid()`; only org owners/admins can `insert/delete` for their org

> Keep it small. Add feature-specific tables per idea (e.g., `invoices`, `notes`, `tasks`) with RLS that requires `EXISTS` membership for the org and/or row-level ownership.

### 5.3 Auth Providers
- Start with **email magic link** (works everywhere).
- Add **Google** quickly; add **Apple** for iOS when needed.
- Mobile uses **Expo AuthSession**; Web uses Next.js API route callbacks or the official helpers.

---

## 6) App Architecture

### 6.1 Feature Modules
Each feature lives in both apps as needed and uses shared building blocks.

```
packages/shared/src/features/<feature>/
  components/
  hooks/
  schemas.ts       # Zod schemas
  types.ts
  queries.ts       # TanStack Query keys & fetchers
apps/mobile/app/(protected)/<feature>/[...].tsx
apps/web/app/(protected)/<feature>/page.tsx
```

- Shared **Zod** schemas drive form validation on both platforms.
- Data fetching via **TanStack Query** using Supabase client under the hood.
- Auth-guarded segments (Expo Router groups & Next.js middleware).

### 6.2 Navigation & Auth Guards
- **Mobile** (Expo Router):
  - `(auth)` group for sign-in/up; `(app)` group for protected routes.
  - Supabase `onAuthStateChange` → update session, redirect.
- **Web** (Next):
  - Middleware checks session cookies for routes under `/app/*`.
  - Server Components can call `createClient(true, cookies)` for safe access.

---

## 7) Developer Experience

- **Generators** (`tools/scripts/create-feature.ts`):
  - Scaffolds `packages/shared/features/<name>` with boilerplate components/schemas/tests.
  - Creates stub screens/routes in both apps.
- **Biome** config in `packages/config/biome.json` shared; simple `pnpm biome` scripts.
- **Consistent scripts** in root `package.json`:
  - `pnpm dev` → run web + mobile concurrently
  - `pnpm lint`, `pnpm typecheck`, `pnpm test`
  - `pnpm gen:feature <name>`
- **Conventional Commits** + **changesets** optional for versioning packages.

---

## 8) CI/CD

**GitHub Actions** (/.github/workflows):
- `ci.yml`: install, typecheck, lint, test, build web.
- Post-merge → deploy **web** to **Vercel** (or Netlify).
- **Expo EAS**: run when you tag or push `release/*` branches.
  - Profiles: `development`, `staging`, `production`
  - OTA updates: `eas update` for small UI fixes (no native changes).

**Envs per stage**:
- Supabase: create `dev`, `staging`, `prod` projects (cheap & simple).
- Expo: use `app.config.ts` to map `APP_ENV` → env file.
- Web: Vercel env aliases for Preview/Production.

---

## 9) Analytics & Monitoring (opt-in)

- **Sentry** SDK in both apps (capture JS errors + sourcemaps).
- **PostHog** for product analytics (events tied to `org_id` / `user_id`); guard with consent flag.
- Add a global `EventBus` util + thin wrapper (`track('event', payload)`) that no-ops if disabled.

---

## 10) Costs (rough, per month)

- **Supabase**: Free → $25 (Pro) when you grow.
- **Vercel**: Free for hobby; $20+ when team/collab expands.
- **Expo EAS**: Free to start; paid for build minutes/priority as needed.
- **Sentry/PostHog**: Free tiers available.

Keeping everything in free tiers is realistic early on.

---

## 11) Roadmap (Phased)

**Phase 0 — Bootstrap (1 day)**
- Initialize Turborepo + pnpm workspaces
- Add apps (Expo, Next), packages (`ui`, `shared`, `supabase`, `config`)
- Add Biome, TypeScript configs, basic scripts

**Phase 1 — Supabase wiring (0.5–1 day)**
- Create Supabase project; set envs
- Create tables (`profiles`, `orgs`, `memberships`) + minimal RLS
- Add auth (email link + Google) and session handling on both apps

**Phase 2 — Feature baseline (1–2 days)**
- Implement `Profile` and `Org switcher` features end-to-end
- Add `settings` screens, light/dark theme, and a shared `DataTable` component
- Add Sentry + PostHog (behind a feature flag)

**Phase 3 — DX & CI (0.5–1 day)**
- Generators (`gen:feature`), GitHub Actions, Vercel deploy
- EAS profiles + first OTA update

**Phase 4 — Database enhancements (0.5 day)**
- Add `updated_at` timestamps to all tables with triggers
- Expand `profiles` table with `timezone`, `locale`, and `preferences` (JSONB)
- Add indexes for frequently queried columns
- Create database migration scripts

**Phase 5 — Auth enhancements (0.5 day)**
- Add password-based authentication alongside magic links
- Implement refresh token rotation
- Add rate limiting for auth endpoints
- Create auth middleware for both platforms

**Phase 6 — Mobile optimizations (1 day)**
- Implement offline support strategy (local storage + sync)
- Add deep linking configuration
- Configure biometric authentication
- Add push notification handling

**Phase 7 — Performance optimizations (0.5–1 day)**
- Add Suspense boundaries and loading states
- Implement image optimization for Supabase Storage
- Configure service worker for web PWA capabilities
- Add React Query prefetching strategies

**Phase 8 — Testing expansion (1 day)**
- Set up E2E testing with Playwright for web
- Add component testing for shared UI
- Implement API mocking strategy
- Create test data generators

**Phase 9 — Documentation & DX (0.5 day)**
- Add API documentation generation
- Create component storybook/documentation
- Add contribution guidelines
- Improve error handling and debugging tools

**Phase 10 — Optional add-ons**
- File uploads to Supabase Storage
- Push notifications (Expo) with serverless function to schedule/trigger
- Payments via Stripe (webhooks in Next API routes; client-side in mobile via Stripe RN SDK)

---

## 12) Commands — From Zero to Running

```bash
# Monorepo
pnpm dlx create-turbo@latest supa-accelerator
cd supa-accelerator
pnpm i

# Add apps (replace the boilerplate apps with Expo + Next)
pnpm dlx create-expo-app apps/mobile --template
pnpm dlx create-next-app@latest apps/web --ts --eslint

# Workspaces (package.json)
# - ensure "apps/*" and "packages/*" are in workspaces

# Shared packages
mkdir -p packages/{ui,shared,supabase,config}
# add tsconfig bases, tamagui config, and initial components

# Install deps
pnpm -w add -D typescript @types/node turbo biome
pnpm -w add zod @tanstack/react-query @tanstack/react-query-devtools
pnpm -w add @supabase/supabase-js
pnpm -w add tamagui react-native-web
# (plus expo-compat deps inside mobile)

# Supabase envs
# apps/mobile: EXPO_PUBLIC_SUPABASE_URL, EXPO_PUBLIC_SUPABASE_ANON_KEY
# apps/web: NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY

# Dev
pnpm --filter web dev
pnpm --filter mobile start
```

---

## 13) Definition of Done (Template v1)

### Core Template (Phases 0-3)
- ✅ Monorepo builds & runs both apps
- ✅ Shared UI via Tamagui with theming + icons
- ✅ Supabase auth + session guard on both apps
- ✅ RLS-secured baseline schema (profiles, orgs, memberships)
- ✅ One example feature (Profile) implemented end-to-end
- ✅ CI (lint, typecheck, tests) + basic deploys (Vercel, EAS profiles)
- ✅ Docs: `README.md` with setup, envs, scripts, and FAQ

### Enhanced Template (Phases 4-9, Optional)
- ⬜ Enhanced database schema with timestamps, indexes, and JSONB
- ⬜ Advanced auth with password, refresh tokens, and rate limiting
- ⬜ Mobile optimizations (offline support, deep linking, biometrics)
- ⬜ Performance optimizations (Suspense, image optimization, PWA)
- ⬜ Expanded testing (E2E, component, API mocking)
- ⬜ Comprehensive documentation (API docs, storybook, contribution guide)

---

## 14) Next Steps for You

### Getting Started (Phases 0-3)
1. Create a new Supabase project (dev) and paste the baseline SQL (profiles/orgs/memberships + policies).
2. Run the commands in **Section 12** to scaffold the repo.
3. Wire envs and confirm login (email magic link).
4. Ship the `Profile` feature; validate RLS with a second account.
5. Decide whether to enable Sentry/PostHog now or later.
6. Use `gen:feature` to start your first startup idea module.

### Enhancement Path (Phases 4-9)
7. Evaluate which enhancements are most valuable for your specific use case.
8. Implement database enhancements from Phase 4 when you need better data tracking.
9. Add auth enhancements from Phase 5 when security becomes more critical.
10. Implement mobile optimizations from Phase 6 when you're ready to improve the native experience.
11. Add performance optimizations from Phase 7 when you need to scale.
12. Expand testing from Phase 8 when stability becomes more important.
13. Improve documentation from Phase 9 when onboarding more developers.

---

### Appendix A — Minimal SQL (starter, edit in Supabase SQL Editor)

```sql
-- Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by owner"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Profiles are updatable by owner"
  on public.profiles for update
  using (auth.uid() = id);

-- orgs
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.orgs enable row level security;

create policy "Org readable by members"
  on public.orgs for select
  using (
    exists (
      select 1 from public.memberships m
      where m.org_id = orgs.id and m.user_id = auth.uid()
    )
  );

create policy "Org updatable by owner"
  on public.orgs for update
  using (owner = auth.uid());

-- memberships
create table if not exists public.memberships (
  org_id uuid not null references public.orgs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member')) default 'member',
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

alter table public.memberships enable row level security;

create policy "Membership viewable by member"
  on public.memberships for select
  using (user_id = auth.uid());

create policy "Membership writable by org owner"
  on public.memberships for insert
  with check (
    exists (
      select 1 from public.orgs o
      where o.id = org_id and o.owner = auth.uid()
    )
  );

create policy "Membership deletable by owner"
  on public.memberships for delete
  using (
    exists (
      select 1 from public.orgs o
      where o.id = org_id and o.owner = auth.uid()
    )
  );
```

### Appendix B — Enhanced SQL (Phase 4 additions)

```sql
-- Add updated_at columns and triggers
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at timestamptz;
ALTER TABLE public.orgs ADD COLUMN IF NOT EXISTS updated_at timestamptz;
ALTER TABLE public.memberships ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers to all tables
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_orgs_updated_at
  BEFORE UPDATE ON public.orgs
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_memberships_updated_at
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enhance profiles table
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS timezone text DEFAULT 'UTC',
  ADD COLUMN IF NOT EXISTS locale text DEFAULT 'en-US',
  ADD COLUMN IF NOT EXISTS preferences jsonb DEFAULT '{}'::jsonb;

-- Add useful indexes
CREATE INDEX IF NOT EXISTS idx_profiles_onboarded ON public.profiles (onboarded);
CREATE INDEX IF NOT EXISTS idx_orgs_owner ON public.orgs (owner);
CREATE INDEX IF NOT EXISTS idx_memberships_user_id ON public.memberships (user_id);
```
