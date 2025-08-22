-- Create user profiles table
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  username text,
  avatar_url text,
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Case-insensitive uniqueness on username (when not null)
create unique index if not exists user_profiles_username_unique
  on public.user_profiles (lower(username)) where username is not null;

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end$$;

drop trigger if exists trg_user_profiles_touch on public.user_profiles;
create trigger trg_user_profiles_touch
before update on public.user_profiles
for each row execute function public.touch_updated_at();

-- Enable row level security
alter table public.user_profiles enable row level security;

-- Owner can read/write their row
create policy "User_Profiles viewable by owner"
  on public.user_profiles for select using (auth.uid() = id);

create policy "User_Profiles updatable by owner"
  on public.user_profiles for update using (auth.uid() = id);

-- Auto-create a profile row on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  -- Insert the new profile with null username
  insert into public.user_profiles (
    id,
    onboarded
  ) values (
    new.id,
    false
  ) on conflict do nothing;
  
  return new;
end$$;

-- Create the trigger on auth.users
drop trigger if exists handle_new_user on auth.users;
create trigger handle_new_user
after insert on auth.users
for each row execute function public.handle_new_user();
