-- 0002_security.sql
-- Row Level Security policies and triggers for automatic profile creation

-- Enable RLS on user_profiles
alter table public.user_profiles enable row level security;

-- User profiles policies
create policy "User profiles viewable by owner"
  on public.user_profiles for select using (auth.uid() = id);

create policy "User profiles updatable by owner"
  on public.user_profiles for update using (auth.uid() = id);

-- Enable RLS on orgs
alter table public.orgs enable row level security;

-- Orgs policies
create policy "orgs_select_member" on public.orgs for select using (
  exists (select 1 from public.memberships m where m.org_id = orgs.id and m.user_id = auth.uid())
);

create policy "orgs_update_owner" on public.orgs for update using (owner = auth.uid());

-- Enable RLS on memberships
alter table public.memberships enable row level security;

-- Memberships policies
create policy "memberships_select_self" on public.memberships for select using (user_id = auth.uid());

create policy "memberships_insert_owner" on public.memberships for insert with check (
  exists (select 1 from public.orgs o where o.id = org_id and o.owner = auth.uid())
);

create policy "memberships_delete_owner" on public.memberships for delete using (
  exists (select 1 from public.orgs o where o.id = org_id and o.owner = auth.uid())
);

-- Auto-create a profile row on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.user_profiles (
    id,
    onboarded,
    timezone,
    locale,
    preferences
  ) values (
    new.id,
    false,
    'UTC',
    'en-US',
    '{}'::jsonb
  ) on conflict do nothing;
  
  return new;
end$$;

-- Create the trigger on auth.users
drop trigger if exists handle_new_user on auth.users;
create trigger handle_new_user
after insert on auth.users
for each row execute function public.handle_new_user();
