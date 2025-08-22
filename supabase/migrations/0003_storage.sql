-- 0003_storage.sql
-- Create storage buckets and policies

-- Create storage buckets
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public) values ('org-files', 'org-files', false)
on conflict (id) do nothing;

-- Policies for avatars (public read, user-owned write)
create policy "avatars_read_all"
on storage.objects for select
to authenticated, anon
using (bucket_id = 'avatars');

create policy "avatars_write_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- Policies for org-files (members only)
create policy "org_files_read_member"
on storage.objects for select
to authenticated
using (
  bucket_id = 'org-files'
  and exists (
    select 1 from public.memberships m
    where m.org_id::text = split_part(name, '/', 1)
      and m.user_id = auth.uid()
  )
);

create policy "org_files_write_member"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'org-files'
  and exists (
    select 1 from public.memberships m
    where m.org_id::text = split_part(name, '/', 1)
      and m.user_id = auth.uid()
  )
);
