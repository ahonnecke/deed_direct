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

Follow these steps to set up your database schema:

```bash
# Login to Supabase (first time only)
make login

# Link to your Supabase project (first time only)
make link

# Sync config from remote project (if needed)
make sync-config

# Check migration status
make list-migrations

# If you encounter migration history errors, fix them first
make fix-migrations

# Apply migrations to your Supabase project
make run-migrations
```

This will apply all migrations in the `supabase/migrations` directory.

### Troubleshooting Migrations

If you encounter errors about migration history not matching, use these commands:

```bash
# List all migrations and their status
make list-migrations

# Automatically fix migration history issues
make fix-migrations
```

The `fix-migrations` command runs a script that intelligently detects which migrations need to be marked as applied and fixes them automatically.
 
## Create profile page /app/profile (read + update)

Outcome: one end-to-end feature showing your patterns (Query + Zod + optimistic UI).
apps/web/app/app/profile/page.tsx

