# Supabase + Expo Accelerator (Template)

A reusable monorepo template for **Next.js (web)** + **Expo (mobile)** with **Supabase**.
This repo is tuned for quick clones and Dockerized web deploys.

## What’s included
- `apps/web` — Next.js 14 (App Router), ready for Docker with `output: 'standalone'`
- `apps/mobile` — Expo Router (stub)
- `packages/ui` — shared UI (Tamagui primitives without Next plugin)
- `packages/shared` — shared utils/types (Zod, TanStack Query ready)
- `packages/supabase` — public/SSR/admin clients split
- `supabase/` — migrations + (optional) Edge Functions skeleton
- `docker-compose.yml` & `Dockerfile` — production-style multi-stage build for the **web** app
- `pnpm` workspaces + `turbo` pipeline

> Note: The Tamagui Next plugin is **disabled** to keep Docker builds deterministic. You can re-enable later when needed.

---

## Requirements
- Node 20+ (recommend `nvm use 20`)
- pnpm 9+ (`corepack enable && corepack use pnpm@9`)
- Docker Desktop or Docker Engine 24+
- A Supabase project (free tier is fine)

---

## 2) Set up Supabase

This project provides a streamlined Supabase setup process that uses direct Supabase CLI commands with fail-fast behavior.

### Option A: Create a new Supabase project

```bash
# Create a new Supabase project (generates secure password, creates project, updates .env)
make create-project
```

This process puts the OLD style api keys into the .env file.
Go to project > settings > api keys
disable "legacy api keys"

go to API Keys tab > "create new api keys"




```bash
# Link to the newly created project and apply migrations in one step
make link-and-migrate
```

### A.2 Set up environment
These values don't exist until after project creation.
Copy the example env file to `.env` (used by Docker Compose and local runs) and fill in keys from your Supabase project.

```bash
cp .env.example .env
```

Required values:
- `NEXT_PUBLIC_SUPABASE_URL` — Supabase API URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — Supabase anon key
- `SUPABASE_URL` — (can be same as public)
- `SUPABASE_ANON_KEY` — (can be same as public)

> Do **not** place your Supabase **SERVICE_ROLE** key in `.env` for the web app.

---


### Option B: Link to an existing Supabase project

```bash
# Login to Supabase (first time only)
make login

# Link to your existing Supabase project and apply migrations in one step
make link-and-migrate

# Or if you prefer separate steps:
# make link
# make run-migrations

# Sync config from remote project (if needed)
make sync-config
```

### Option C: Complete setup in one command

```bash
# Run the complete setup process (create project, link, and run migrations)
make setup
```

The migrations are organized in a clean sequence:
- **0001_base.sql**: Core tables (`user_profiles`, `orgs`, `memberships`) and triggers
- **0002_security.sql**: RLS policies and automatic profile creation
- **0003_storage.sql**: Storage buckets for avatars and organization files

---

## 3a) Run the web app with Docker (recommended)
```bash
docker compose up --build web
# open http://localhost:3000
# protected area: http://localhost:3000/app
```

## 3b) Run the web app locally (no Docker)
```bash
pnpm install
pnpm --filter web dev
# open http://localhost:3000
```

> Mobile (`apps/mobile`) is stubbed and not containerized yet. You can run it with `pnpm --filter mobile dev` after installing Expo CLI prerequisites.

---

## Project scripts
At the repo root:
- `pnpm dev` — run apps via turbo filters (configured to run web + mobile in parallel if desired)
- `pnpm build` — build all packages/apps
- `pnpm typecheck` — TypeScript check across the monorepo
- `pnpm test` — (placeholder) runs tests across the monorepo

Web app (`apps/web`):
- `pnpm --filter web dev`
- `pnpm --filter web build`
- `pnpm --filter web start`

Mobile app (`apps/mobile`):
- `pnpm --filter mobile dev` (Expo)

---

## Template usage
Make this a GitHub **Template Repository**:
1. Push to GitHub.
2. In repo **Settings → General → Template repository** → enable.
3. New projects can now click **Use this template** to clone a fresh copy.

If you prefer CLI scaffolding later, consider publishing a small `create-*` tool that pulls this repo and writes `.env` from prompts.

---

## Re-introducing Tamagui Next plugin (optional, later)
When you want web-side extraction/optimizations:
1. Add the plugin to the web app: `pnpm --filter web add -D @tamagui/next-plugin`
2. Use ESM **named import** in `apps/web/next.config.mjs`:
   ```js
   import { withTamagui } from '@tamagui/next-plugin'
   const withPlugins = withTamagui({
     config: '../../packages/ui/tamagui.config.ts',
     components: ['@supa/ui'],
     disableExtract: process.env.NODE_ENV === 'development',
   })
   export default withPlugins({ output: 'standalone', transpilePackages: ['react-native-web','tamagui','@tamagui/*','@supa/ui','@supa/shared','@supa/supabase'] })
   ```

---

## Next steps (recommended order)
1. Add a simple **/sign-in** page (magic link) and redirect to **/app** on success.
2. Implement `/app/profile` against the `user_profiles` table (Zod form + TanStack Query).
3. Add CI (GitHub Actions): typecheck, test, **Docker build** for the web image.
4. (Optional) Push image to a registry and deploy your container.
5. Circle back to mobile: wire Supabase auth and a matching profile screen.

---

## Troubleshooting
- **Docker build fails copying `public/`** → ensure `apps/web/public/` exists (empty `.gitignore` is fine).
- **Edge runtime warnings** with Supabase in middleware → split clients into `client.browser.ts` and `client.ssr.ts` and import the correct one per runtime.
- **pnpm workspace not recognized** → ensure `pnpm-workspace.yaml` includes `apps/*` and `packages/*`.
- **Supabase setup hangs** → the scripts use fail-fast behavior, so check your Supabase login status with `npx supabase projects list` and ensure your network connection is stable.

---

## License
MIT (or your preferred license)
