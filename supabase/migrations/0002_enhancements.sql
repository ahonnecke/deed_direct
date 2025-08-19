-- 0002_enhancements.sql
-- updated_at columns + triggers + indexes + profile extras
alter table public.profiles add column if not exists updated_at timestamptz;
alter table public.orgs add column if not exists updated_at timestamptz;
alter table public.memberships add column if not exists updated_at timestamptz;

create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

create trigger set_orgs_updated_at
  before update on public.orgs
  for each row execute function public.handle_updated_at();

create trigger set_memberships_updated_at
  before update on public.memberships
  for each row execute function public.handle_updated_at();

alter table public.profiles 
  add column if not exists timezone text default 'UTC',
  add column if not exists locale text default 'en-US',
  add column if not exists preferences jsonb default '{}'::jsonb;

create index if not exists idx_profiles_onboarded on public.profiles (onboarded);
create index if not exists idx_orgs_owner on public.orgs (owner);
create index if not exists idx_memberships_user_id on public.memberships (user_id);
