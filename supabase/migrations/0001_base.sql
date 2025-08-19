-- 0001_base.sql
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
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- orgs
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.orgs enable row level security;
create policy "orgs_select_member" on public.orgs for select using (
  exists (select 1 from public.memberships m where m.org_id = orgs.id and m.user_id = auth.uid())
);
create policy "orgs_update_owner" on public.orgs for update using (owner = auth.uid());

-- memberships
create table if not exists public.memberships (
  org_id uuid not null references public.orgs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member')) default 'member',
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);
alter table public.memberships enable row level security;
create policy "memberships_select_self" on public.memberships for select using (user_id = auth.uid());
create policy "memberships_insert_owner" on public.memberships for insert with check (
  exists (select 1 from public.orgs o where o.id = org_id and o.owner = auth.uid())
);
create policy "memberships_delete_owner" on public.memberships for delete using (
  exists (select 1 from public.orgs o where o.id = org_id and o.owner = auth.uid())
);
