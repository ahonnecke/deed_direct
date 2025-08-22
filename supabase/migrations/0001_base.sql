-- 0001_base.sql
-- Base extensions and core tables

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- User Profiles
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  username text,
  avatar_url text,
  onboarded boolean not null default false,
  timezone text default 'UTC',
  locale text default 'en-US',
  preferences jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Case-insensitive uniqueness on username (when not null)
create unique index if not exists user_profiles_username_unique
  on public.user_profiles (lower(username)) where username is not null;

-- Organizations
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Memberships
create table if not exists public.memberships (
  org_id uuid not null references public.orgs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member')) default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  primary key (org_id, user_id)
);

-- Updated_at trigger function
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Set up triggers for updated_at
create trigger set_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.handle_updated_at();

create trigger set_orgs_updated_at
  before update on public.orgs
  for each row execute function public.handle_updated_at();

create trigger set_memberships_updated_at
  before update on public.memberships
  for each row execute function public.handle_updated_at();

-- Indexes
create index if not exists idx_user_profiles_onboarded on public.user_profiles (onboarded);
create index if not exists idx_orgs_owner on public.orgs (owner);
create index if not exists idx_memberships_user_id on public.memberships (user_id);
