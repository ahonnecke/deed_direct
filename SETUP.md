# Steps to set up a new approach

Yeah, that wording was shorthand. Here’s exactly what it means, step-by-step in the Supabase dashboard UI:

1. Go to [Supabase](https://app.supabase.com/) and open your project.
2. In the left sidebar, click **Authentication → URL Configuration**.
   (It’s under the “Authentication” section; sometimes it’s just labeled **Auth Settings** depending on UI version).
3. Find the field called **Redirect URLs**. This is the whitelist of allowed callback URLs where Supabase is allowed to send users after sign-in / magic link.
4. Paste in:

   ```
   http://localhost:3000
   ```

   That matches the web app you’re running locally with `docker compose up web`.
   
   --ashton (this is what is already was)
5. (Optional but useful) Also add your production domain here once you deploy, e.g.:

   ```
   https://myapp.com
   ```
6. Hit **Save** at the bottom.

Why: when a user clicks the magic link Supabase sends in email, Supabase will redirect them back to whatever `emailRedirectTo` you passed in your code (in this case `${window.location.origin}/app`, which will be `http://localhost:3000/app`). If `http://localhost:3000` isn’t on the whitelist, Supabase rejects the redirect.
