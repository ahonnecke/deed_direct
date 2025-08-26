# Admin Dashboard

## Overview
The Admin Dashboard provides a centralized interface for administrators to manage users, monitor system activity, view analytics, and control application settings. It's a protected area accessible only to users with admin privileges.

## Purpose
To give administrators and business stakeholders powerful tools to oversee the application's operation, manage users, and make data-driven decisions without requiring developer intervention.

## Technical Implementation

### Database Schema Updates
```sql
-- Add admin flag to user_profiles
alter table public.user_profiles add column if not exists is_admin boolean not null default false;

-- Create admin activity log
create table if not exists public.admin_activity (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Create admin settings table
create table if not exists public.admin_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

-- Add indexes
create index if not exists idx_admin_activity_admin_id on public.admin_activity (admin_id);
create index if not exists idx_admin_activity_action on public.admin_activity (action);
create index if not exists idx_user_profiles_is_admin on public.user_profiles (is_admin);

-- Add RLS policies
alter table public.admin_activity enable row level security;
alter table public.admin_settings enable row level security;

-- Only admins can view admin activity
create policy "Admins can view admin activity"
  on public.admin_activity for select
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Only admins can insert admin activity
create policy "Admins can insert admin activity"
  on public.admin_activity for insert
  with check (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Only admins can view admin settings
create policy "Admins can view admin settings"
  on public.admin_settings for select
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Only admins can update admin settings
create policy "Admins can update admin settings"
  on public.admin_settings for update
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));
```

### Required Packages
```bash
pnpm add recharts @tanstack/react-table react-hook-form zod @hookform/resolvers
```

### Implementation Steps

1. **Create Admin Layout**
   ```typescript
   // apps/web/app/admin/layout.tsx
   import { redirect } from 'next/navigation';
   import { createSSRClient } from '@supa/supabase';
   import { AdminSidebar } from './components/AdminSidebar';
   
   export default async function AdminLayout({ children }) {
     // Check if user is admin
     const supabase = createSSRClient();
     const { data: { session } } = await supabase.auth.getSession();
     
     if (!session) {
       redirect('/sign-in');
     }
     
     // Get user profile to check admin status
     const { data: profile } = await supabase
       .from('user_profiles')
       .select('is_admin')
       .eq('id', session.user.id)
       .single();
     
     if (!profile || !profile.is_admin) {
       redirect('/app'); // Redirect non-admins
     }
     
     // Log admin access
     await supabase
       .from('admin_activity')
       .insert({
         admin_id: session.user.id,
         action: 'access',
         entity_type: 'admin_dashboard',
       });
     
     return (
       <div className="admin-layout">
         <AdminSidebar />
         <main className="admin-content">
           {children}
         </main>
       </div>
     );
   }
   ```

2. **Create Admin Dashboard Home**
   ```typescript
   // apps/web/app/admin/page.tsx
   import { createSSRClient } from '@supa/supabase';
   import { AdminStats } from './components/AdminStats';
   import { RecentActivity } from './components/RecentActivity';
   import { QuickActions } from './components/QuickActions';
   
   export default async function AdminDashboard() {
     const supabase = createSSRClient();
     
     // Get high-level stats
     const { data: userCount } = await supabase
       .from('user_profiles')
       .select('id', { count: 'exact', head: true });
     
     const { data: recentActivity } = await supabase
       .from('admin_activity')
       .select('*')
       .order('created_at', { ascending: false })
       .limit(10);
     
     // Get other relevant stats based on your application
     // e.g., subscription stats, feedback counts, etc.
     
     return (
       <div className="admin-dashboard">
         <h1>Admin Dashboard</h1>
         
         <AdminStats 
           userCount={userCount || 0}
           // Add other stats here
         />
         
         <div className="dashboard-grid">
           <QuickActions />
           <RecentActivity activity={recentActivity || []} />
           {/* Add other dashboard widgets */}
         </div>
       </div>
     );
   }
   ```

3. **Create User Management Page**
   ```typescript
   // apps/web/app/admin/users/page.tsx
   import { createSSRClient } from '@supa/supabase';
   import { UserTable } from './components/UserTable';
   
   export default async function AdminUsers() {
     const supabase = createSSRClient();
     
     const { data: users, error } = await supabase
       .from('user_profiles')
       .select('id, first_name, last_name, email:auth.users(email), created_at, is_admin')
       .order('created_at', { ascending: false });
     
     if (error) {
       console.error('Error fetching users:', error);
     }
     
     return (
       <div className="admin-users">
         <h1>User Management</h1>
         <UserTable users={users || []} />
       </div>
     );
   }
   ```

4. **Create User Detail/Edit Page**
   ```typescript
   // apps/web/app/admin/users/[id]/page.tsx
   import { notFound } from 'next/navigation';
   import { createSSRClient } from '@supa/supabase';
   import { UserForm } from '../components/UserForm';
   
   export default async function AdminUserDetail({ params }) {
     const { id } = params;
     const supabase = createSSRClient();
     
     const { data: user, error } = await supabase
       .from('user_profiles')
       .select('*, email:auth.users(email)')
       .eq('id', id)
       .single();
     
     if (error || !user) {
       notFound();
     }
     
     return (
       <div className="admin-user-detail">
         <h1>Edit User: {user.first_name} {user.last_name}</h1>
         <UserForm user={user} />
       </div>
     );
   }
   ```

5. **Create Settings Management**
   ```typescript
   // apps/web/app/admin/settings/page.tsx
   'use client';
   
   import { useState, useEffect } from 'react';
   import { useForm } from 'react-hook-form';
   import { createPublicClient } from '@supa/supabase';
   
   export default function AdminSettings() {
     const [settings, setSettings] = useState({});
     const [isLoading, setIsLoading] = useState(true);
     const { register, handleSubmit, reset } = useForm();
     
     useEffect(() => {
       async function loadSettings() {
         const supabase = createPublicClient();
         const { data, error } = await supabase
           .from('admin_settings')
           .select('*');
         
         if (!error && data) {
           // Transform array to object for easier form handling
           const settingsObj = data.reduce((acc, setting) => {
             acc[setting.key] = setting.value;
             return acc;
           }, {});
           
           setSettings(settingsObj);
           reset(settingsObj);
         }
         
         setIsLoading(false);
       }
       
       loadSettings();
     }, [reset]);
     
     const onSubmit = async (data) => {
       const supabase = createPublicClient();
       
       // Convert form data to array of settings
       const updates = Object.entries(data).map(([key, value]) => ({
         key,
         value,
       }));
       
       // Update settings
       for (const setting of updates) {
         await supabase
           .from('admin_settings')
           .upsert(setting, { onConflict: 'key' });
       }
       
       // Log activity
       await supabase
         .from('admin_activity')
         .insert({
           admin_id: (await supabase.auth.getUser()).data.user.id,
           action: 'update',
           entity_type: 'settings',
           details: { updated: Object.keys(data) },
         });
       
       alert('Settings updated successfully');
     };
     
     if (isLoading) return <div>Loading settings...</div>;
     
     return (
       <div className="admin-settings">
         <h1>Application Settings</h1>
         
         <form onSubmit={handleSubmit(onSubmit)}>
           {/* Render form fields dynamically based on settings */}
           {Object.entries(settings).map(([key, value]) => (
             <div key={key} className="form-group">
               <label htmlFor={key}>{key.replace(/_/g, ' ')}</label>
               <input
                 id={key}
                 type="text"
                 {...register(key)}
                 defaultValue={value}
               />
             </div>
           ))}
           
           <button type="submit">Save Settings</button>
         </form>
       </div>
     );
   }
   ```

6. **Create Admin Components**
   ```typescript
   // apps/web/app/admin/components/AdminSidebar.tsx
   import Link from 'next/link';
   
   export function AdminSidebar() {
     const menuItems = [
       { label: 'Dashboard', href: '/admin', icon: 'dashboard' },
       { label: 'Users', href: '/admin/users', icon: 'users' },
       { label: 'Feedback', href: '/admin/feedback', icon: 'feedback' },
       { label: 'Settings', href: '/admin/settings', icon: 'settings' },
       // Add more menu items based on your application
     ];
     
     return (
       <aside className="admin-sidebar">
         <div className="admin-sidebar-header">
           <h2>Admin</h2>
         </div>
         
         <nav className="admin-nav">
           <ul>
             {menuItems.map((item) => (
               <li key={item.href}>
                 <Link href={item.href}>
                   <span className={`icon ${item.icon}`}></span>
                   <span>{item.label}</span>
                 </Link>
               </li>
             ))}
           </ul>
         </nav>
         
         <div className="admin-sidebar-footer">
           <Link href="/app">
             Exit Admin
           </Link>
         </div>
       </aside>
     );
   }
   ```

7. **Create Admin API Routes**
   ```typescript
   // apps/web/app/api/admin/users/route.ts
   import { NextResponse } from 'next/server';
   import { createSSRClient } from '@supa/supabase';
   
   export async function GET(request) {
     const supabase = createSSRClient();
     
     // Check if user is admin
     const { data: { session } } = await supabase.auth.getSession();
     
     if (!session) {
       return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
     }
     
     const { data: profile } = await supabase
       .from('user_profiles')
       .select('is_admin')
       .eq('id', session.user.id)
       .single();
     
     if (!profile || !profile.is_admin) {
       return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
     }
     
     // Process the request
     const { data, error } = await supabase
       .from('user_profiles')
       .select('*');
     
     if (error) {
       return NextResponse.json({ error: error.message }, { status: 500 });
     }
     
     return NextResponse.json({ data });
   }
   ```

8. **Create Admin Middleware**
   ```typescript
   // apps/web/middleware.ts
   // Add to existing middleware
   
   // Protect admin routes
   export const config = {
     matcher: ['/app/:path*', '/admin/:path*'],
   };
   
   export async function middleware(request) {
     // ... existing auth checks
     
     // Additional check for admin routes
     if (request.nextUrl.pathname.startsWith('/admin')) {
       const supabase = createServerClient(
         // ... your existing config
       );
       
       const { data: { session } } = await supabase.auth.getSession();
       
       if (!session) {
         return NextResponse.redirect(new URL('/sign-in', request.url));
       }
       
       const { data: profile } = await supabase
         .from('user_profiles')
         .select('is_admin')
         .eq('id', session.user.id)
         .single();
       
       if (!profile || !profile.is_admin) {
         return NextResponse.redirect(new URL('/app', request.url));
       }
     }
     
     return NextResponse.next();
   }
   ```

## Security Considerations
- Implement strict RLS policies for admin-only tables
- Use middleware to protect all admin routes
- Log all admin actions for audit purposes
- Implement rate limiting on admin API endpoints
- Consider IP restrictions for admin access
- Use strong CSRF protection for admin forms

## User Experience Considerations
- Design a clean, intuitive admin interface
- Provide clear feedback for admin actions
- Include confirmation dialogs for destructive actions
- Implement responsive design for mobile admin access
- Add keyboard shortcuts for common admin tasks

## Testing
- Test admin authentication and authorization
- Test all CRUD operations on admin-managed data
- Test admin activity logging
- Test settings management
- Test user impersonation (if implemented)

## Deployment Checklist
- Ensure database migrations are applied
- Verify RLS policies are working correctly
- Test the complete admin workflow in production
- Set up monitoring for admin actions
- Create initial admin user(s)
