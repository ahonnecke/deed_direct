# Steps to set up a new approach
## Set up URLs

Yeah, that wording was shorthand. Here’s exactly what it means, step-by-step in the Supabase dashboard UI:

1. Go to [Supabase](https://app.supabase.com/) and open your project.
2. In the left sidebar, click **Authentication → URL Configuration**.
   (It’s under the “Authentication” section; sometimes it’s just labeled **Auth Settings** depending on UI version).
3. Find the field called **Redirect URLs**. This is the whitelist of allowed callback URLs where Supabase is allowed to send users after sign-in / magic link.
4. Ensure it says:

   ```
   http://localhost:3000
   ```

   That matches the web app you’re running locally with `docker compose up web`.
5. (Optional but useful) Also add your production domain here once you deploy, e.g.:

   ```
   https://myapp.com
   ```
6. Hit **Save** at the bottom.

## Set up ENV vars

What you need to fill in

Go to your Supabase dashboard → your project → Settings → API.

You’ll see:

Project URL (https://xyzcompany.supabase.co)

Go to API Keys

Go to Legacy API Keys
Copy the anon public key to env vars
Reveal and copy the service role to env vars


## Create profiles tables

Run this in Supabase SQL Editor:

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create policy "Profiles viewable by owner"
  on public.profiles for select using (auth.uid() = id);

create policy "Profiles updatable by owner"
  on public.profiles for update using (auth.uid() = id);

-- ensure a profile row exists after signup (Edge Function optional later)

## Create profile page /app/profile (read + update)

Outcome: one end-to-end feature showing your patterns (Query + Zod + optimistic UI).
apps/web/app/app/profile/page.tsx

