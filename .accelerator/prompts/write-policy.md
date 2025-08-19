# Prompt: Write RLS Policy

Given table name, ownership concept (user_id/org_id), and allowed actions, produce:
- Minimal, *least privilege* policies for select/insert/update/delete.
- Use `auth.uid()` and `exists (select 1 from memberships ...)` for org-based checks.
- Do not use `grant all`; write separate policies per action.
- Include brief SQL comments explaining intent.
Output: valid SQL only.
