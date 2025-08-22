# Supabase Setup Guide

## Automated Setup (Recommended)

This project includes an automated setup script that handles the entire Supabase setup process in one command:

```bash
make setup
```

This command will:

1. Create a new Supabase project (or use an existing one with the same name)
2. Link your local repository to the Supabase project
3. Set up all necessary environment variables in your `.env` file
4. Configure authentication settings (redirect URLs)
5. Apply all database migrations

You can optionally specify a project name as an argument to the setup script:

```bash
./tools/scripts/setup.sh my-project-name
```

Note: this fails on the password step (at the least when the project exists,
maybe when new as well).

What did work was:
- `make setup` > fail
- manually reset the db pw
- `make setup` > enter the new db pw

## Manual Setup

If you prefer to set up manually, follow these steps:

### 1. Create a new Supabase project
- Go to [Supabase](https://app.supabase.com/) and create a new project

### 2. Set up environment variables
- Go to your Supabase dashboard → your project → Settings → API
- Copy the Project URL (https://your-project.supabase.co)
- Go to API Keys and copy the anon/public key
- Add these to your `.env` file:
  ```
  NEXT_PUBLIC_SUPABASE_URL=your_project_url
  NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
  SUPABASE_URL=your_project_url
  SUPABASE_ANON_KEY=your_anon_key
  ```

### 3. Link and configure Supabase

```bash
# Login to Supabase (first time only)
make login

# Link to your Supabase project
make link

# Sync config from remote project
make sync-config

# Apply migrations to your Supabase project
make run-migrations
```

### 4. Configure Authentication URLs

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



## Database Schema

The database schema is organized into three clean migrations:

### 1. Base Schema (0001_base.sql)

- **User Profiles**: Complete user profile table with all fields
- **Organizations**: For team/multi-user functionality
- **Memberships**: Connects users to organizations with roles
- **Triggers**: For automatic timestamp updates

### 2. Security (0002_security.sql)

- **Row Level Security**: Policies for all tables
- **Auto-Profile Creation**: Trigger to create profiles on signup

### 3. Storage (0003_storage.sql)

- **Storage Buckets**: For avatars (public) and organization files (private)
- **Access Policies**: Security rules for file access

### Database Setup

The database setup is handled automatically by the `make setup` command. If you need to run migrations separately, use:

```bash
make run-migrations
```

This will apply all migrations in the `supabase/migrations` directory.

### Troubleshooting Migrations

If you encounter errors about migration history not matching, use these commands:

```bash
# List all migrations and their status
make list-migrations
```

The migrations are designed to be applied cleanly to a fresh database without any conflicts.
 
## Create profile page /app/profile (read + update)

### User Profile Schema

The user profile table (`user_profiles`) has the following structure:

```sql
create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  username text,  -- Optional, unique when provided
  avatar_url text,
  onboarded boolean not null default false,
  timezone text default 'UTC',
  locale text default 'en-US',
  preferences jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

A profile is automatically created for each new user via a trigger on the `auth.users` table.

When implementing the profile page, you can access this table to read and update user information.

Outcome: one end-to-end feature showing your patterns (Query + Zod + optimistic UI).
apps/web/app/app/profile/page.tsx

