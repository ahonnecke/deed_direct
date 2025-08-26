# Analytics Integration

## Overview
The Analytics Integration feature provides comprehensive tracking and analysis of user behavior within the application. It includes privacy controls, opt-out functionality, and a dashboard for visualizing key metrics.

## Purpose
To gather actionable insights about user behavior, feature usage, and business performance while respecting user privacy preferences and data regulations.

## Technical Implementation

### Database Schema
```sql
-- Add to migrations
create table if not exists public.analytics_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  allow_usage_tracking boolean not null default true,
  allow_error_reporting boolean not null default true,
  anonymize_data boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id text not null,
  event_name text not null,
  event_properties jsonb default '{}'::jsonb,
  user_properties jsonb default '{}'::jsonb,
  device_info jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Add indexes for faster queries
create index if not exists idx_analytics_events_user_id on public.analytics_events (user_id);
create index if not exists idx_analytics_events_event_name on public.analytics_events (event_name);
create index if not exists idx_analytics_events_created_at on public.analytics_events (created_at);

-- Add RLS policies
alter table public.analytics_preferences enable row level security;
alter table public.analytics_events enable row level security;

-- Users can view and update their own analytics preferences
create policy "Users can view their own analytics preferences"
  on public.analytics_preferences for select
  using (auth.uid() = user_id);

create policy "Users can update their own analytics preferences"
  on public.analytics_preferences for update
  using (auth.uid() = user_id);

-- Only admins can view analytics events
create policy "Admins can view analytics events"
  on public.analytics_events for select
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));
```

### Required Packages
```bash
pnpm add uuid @amplitude/analytics-browser recharts
```

### Implementation Steps

1. **Create Analytics Client**
   ```typescript
   // packages/shared/src/analytics/client.ts
   import { createBrowserClient } from '@supabase/ssr';
   import { v4 as uuidv4 } from 'uuid';
   import * as amplitude from '@amplitude/analytics-browser';

   // Initialize session ID
   const SESSION_ID = typeof window !== 'undefined' ? 
     localStorage.getItem('analytics_session_id') || uuidv4() : 
     uuidv4();

   if (typeof window !== 'undefined') {
     localStorage.setItem('analytics_session_id', SESSION_ID);
   }

   // Initialize third-party analytics (optional)
   export const initializeAnalytics = (apiKey: string) => {
     if (typeof window !== 'undefined') {
       amplitude.init(apiKey, undefined, {
         defaultTracking: false,
       });
     }
   };

   // Get user's analytics preferences
   export const getAnalyticsPreferences = async () => {
     const supabase = createBrowserClient(
       process.env.NEXT_PUBLIC_SUPABASE_URL!,
       process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
     );
     
     const { data: { user } } = await supabase.auth.getUser();
     
     if (!user) {
       return {
         allow_usage_tracking: true,
         allow_error_reporting: true,
         anonymize_data: false,
       };
     }
     
     const { data, error } = await supabase
       .from('analytics_preferences')
       .select('*')
       .eq('user_id', user.id)
       .single();
     
     if (error || !data) {
       // Create default preferences
       const { data: newPrefs } = await supabase
         .from('analytics_preferences')
         .insert({
           user_id: user.id,
           allow_usage_tracking: true,
           allow_error_reporting: true,
           anonymize_data: false,
         })
         .select()
         .single();
       
       return newPrefs || {
         allow_usage_tracking: true,
         allow_error_reporting: true,
         anonymize_data: false,
       };
     }
     
     return data;
   };

   // Track event
   export const trackEvent = async (
     eventName: string,
     eventProperties: Record<string, any> = {},
     userProperties: Record<string, any> = {}
   ) => {
     try {
       const prefs = await getAnalyticsPreferences();
       
       // Respect user preferences
       if (!prefs.allow_usage_tracking) {
         return;
       }
       
       const supabase = createBrowserClient(
         process.env.NEXT_PUBLIC_SUPABASE_URL!,
         process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
       );
       
       const { data: { user } } = await supabase.auth.getUser();
       
       // Get device info
       const deviceInfo = {
         userAgent: navigator.userAgent,
         language: navigator.language,
         screenWidth: window.screen.width,
         screenHeight: window.screen.height,
         viewportWidth: window.innerWidth,
         viewportHeight: window.innerHeight,
       };
       
       // Anonymize data if requested
       const userId = prefs.anonymize_data ? null : user?.id;
       const anonymizedProps = prefs.anonymize_data ? 
         anonymizeProperties(eventProperties) : 
         eventProperties;
       
       // Store event in Supabase
       await supabase
         .from('analytics_events')
         .insert({
           user_id: userId,
           session_id: SESSION_ID,
           event_name: eventName,
           event_properties: anonymizedProps,
           user_properties: prefs.anonymize_data ? {} : userProperties,
           device_info: deviceInfo,
         });
       
       // Send to third-party analytics (if configured)
       if (process.env.NEXT_PUBLIC_AMPLITUDE_API_KEY) {
         amplitude.track(eventName, anonymizedProps);
       }
     } catch (error) {
       console.error('Error tracking event:', error);
     }
   };

   // Helper to anonymize sensitive data
   const anonymizeProperties = (props: Record<string, any>) => {
     const result = { ...props };
     
     // Remove any potentially identifying information
     const keysToAnonymize = ['email', 'name', 'phone', 'address', 'ip', 'location'];
     
     for (const key of Object.keys(result)) {
       if (keysToAnonymize.some(k => key.toLowerCase().includes(k))) {
         delete result[key];
       }
     }
     
     return result;
   };

   // Track page view
   export const trackPageView = (pageName: string, pageProperties: Record<string, any> = {}) => {
     trackEvent('page_view', {
       page_name: pageName,
       page_url: typeof window !== 'undefined' ? window.location.href : '',
       referrer: typeof document !== 'undefined' ? document.referrer : '',
       ...pageProperties,
     });
   };

   // Track error
   export const trackError = async (error: Error, context: Record<string, any> = {}) => {
     try {
       const prefs = await getAnalyticsPreferences();
       
       // Respect user preferences
       if (!prefs.allow_error_reporting) {
         return;
       }
       
       trackEvent('error', {
         error_name: error.name,
         error_message: error.message,
         error_stack: error.stack,
         ...context,
       });
     } catch (e) {
       console.error('Error tracking error:', e);
     }
   };
   ```

2. **Create Analytics Provider**
   ```typescript
   // packages/shared/src/analytics/provider.tsx
   'use client';
   
   import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
   import { initializeAnalytics, trackPageView, trackEvent, trackError, getAnalyticsPreferences } from './client';
   
   interface AnalyticsContextType {
     trackEvent: typeof trackEvent;
     trackError: typeof trackError;
     preferences: {
       allow_usage_tracking: boolean;
       allow_error_reporting: boolean;
       anonymize_data: boolean;
     } | null;
     isLoading: boolean;
     updatePreferences: (prefs: Partial<{
       allow_usage_tracking: boolean;
       allow_error_reporting: boolean;
       anonymize_data: boolean;
     }>) => Promise<void>;
   }
   
   const AnalyticsContext = createContext<AnalyticsContextType>({
     trackEvent,
     trackError,
     preferences: null,
     isLoading: true,
     updatePreferences: async () => {},
   });
   
   export const useAnalytics = () => useContext(AnalyticsContext);
   
   interface AnalyticsProviderProps {
     children: ReactNode;
   }
   
   export function AnalyticsProvider({ children }: AnalyticsProviderProps) {
     const [preferences, setPreferences] = useState<{
       allow_usage_tracking: boolean;
       allow_error_reporting: boolean;
       anonymize_data: boolean;
     } | null>(null);
     const [isLoading, setIsLoading] = useState(true);
     
     useEffect(() => {
       // Initialize analytics
       if (process.env.NEXT_PUBLIC_AMPLITUDE_API_KEY) {
         initializeAnalytics(process.env.NEXT_PUBLIC_AMPLITUDE_API_KEY);
       }
       
       // Load user preferences
       const loadPreferences = async () => {
         try {
           const prefs = await getAnalyticsPreferences();
           setPreferences(prefs);
         } catch (error) {
           console.error('Error loading analytics preferences:', error);
         } finally {
           setIsLoading(false);
         }
       };
       
       loadPreferences();
     }, []);
     
     // Track page views
     useEffect(() => {
       if (!isLoading && preferences?.allow_usage_tracking && typeof window !== 'undefined') {
         const handleRouteChange = (url: string) => {
           trackPageView(url);
         };
         
         // Track initial page view
         trackPageView(window.location.pathname);
         
         // Set up route change tracking
         window.addEventListener('popstate', () => handleRouteChange(window.location.pathname));
         
         return () => {
           window.removeEventListener('popstate', () => handleRouteChange(window.location.pathname));
         };
       }
     }, [isLoading, preferences]);
     
     // Update preferences
     const updatePreferences = async (prefs: Partial<{
       allow_usage_tracking: boolean;
       allow_error_reporting: boolean;
       anonymize_data: boolean;
     }>) => {
       try {
         const supabase = createBrowserClient(
           process.env.NEXT_PUBLIC_SUPABASE_URL!,
           process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
         );
         
         const { data: { user } } = await supabase.auth.getUser();
         
         if (!user) {
           throw new Error('User not authenticated');
         }
         
         const { data, error } = await supabase
           .from('analytics_preferences')
           .update({
             ...prefs,
             updated_at: new Date().toISOString(),
           })
           .eq('user_id', user.id)
           .select()
           .single();
         
         if (error) {
           throw error;
         }
         
         setPreferences(data);
       } catch (error) {
         console.error('Error updating analytics preferences:', error);
         throw error;
       }
     };
     
     return (
       <AnalyticsContext.Provider
         value={{
           trackEvent,
           trackError,
           preferences,
           isLoading,
           updatePreferences,
         }}
       >
         {children}
       </AnalyticsContext.Provider>
     );
   }
   ```

3. **Create Analytics Dashboard**
   ```typescript
   // apps/web/app/admin/analytics/page.tsx
   'use client';
   
   import { useState, useEffect } from 'react';
   import { createPublicClient } from '@supa/supabase';
   import {
     LineChart, Line, BarChart, Bar, PieChart, Pie,
     XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
   } from 'recharts';
   
   export default function AnalyticsDashboard() {
     const [timeframe, setTimeframe] = useState('7d');
     const [eventCounts, setEventCounts] = useState([]);
     const [pageViews, setPageViews] = useState([]);
     const [userActivity, setUserActivity] = useState([]);
     const [isLoading, setIsLoading] = useState(true);
     
     useEffect(() => {
       const fetchAnalytics = async () => {
         setIsLoading(true);
         const supabase = createPublicClient();
         
         // Calculate date range based on timeframe
         const now = new Date();
         let startDate = new Date();
         
         switch (timeframe) {
           case '24h':
             startDate.setDate(now.getDate() - 1);
             break;
           case '7d':
             startDate.setDate(now.getDate() - 7);
             break;
           case '30d':
             startDate.setDate(now.getDate() - 30);
             break;
           case '90d':
             startDate.setDate(now.getDate() - 90);
             break;
         }
         
         // Fetch event counts
         const { data: events } = await supabase
           .from('analytics_events')
           .select('event_name, created_at')
           .gte('created_at', startDate.toISOString())
           .order('created_at', { ascending: true });
         
         // Process event counts
         const eventsByName = events?.reduce((acc, event) => {
           acc[event.event_name] = (acc[event.event_name] || 0) + 1;
           return acc;
         }, {});
         
         setEventCounts(Object.entries(eventsByName || {}).map(([name, count]) => ({
           name,
           count,
         })));
         
         // Fetch page views
         const { data: views } = await supabase
           .from('analytics_events')
           .select('event_properties, created_at')
           .eq('event_name', 'page_view')
           .gte('created_at', startDate.toISOString())
           .order('created_at', { ascending: true });
         
         // Process page views
         const pageViewsByPath = views?.reduce((acc, view) => {
           const path = view.event_properties.page_name || 'unknown';
           acc[path] = (acc[path] || 0) + 1;
           return acc;
         }, {});
         
         setPageViews(Object.entries(pageViewsByPath || {}).map(([path, count]) => ({
           path,
           count,
         })));
         
         // Fetch user activity
         const { data: activity } = await supabase
           .from('analytics_events')
           .select('user_id, created_at')
           .not('user_id', 'is', null)
           .gte('created_at', startDate.toISOString());
         
         // Process user activity
         const userActivityByDate = activity?.reduce((acc, event) => {
           const date = new Date(event.created_at).toLocaleDateString();
           
           if (!acc[date]) {
             acc[date] = new Set();
           }
           
           acc[date].add(event.user_id);
           return acc;
         }, {});
         
         const userActivityData = Object.entries(userActivityByDate || {}).map(([date, users]) => ({
           date,
           users: (users as Set<string>).size,
         }));
         
         setUserActivity(userActivityData);
         setIsLoading(false);
       };
       
       fetchAnalytics();
     }, [timeframe]);
     
     if (isLoading) {
       return <div>Loading analytics data...</div>;
     }
     
     return (
       <div className="analytics-dashboard">
         <h1>Analytics Dashboard</h1>
         
         <div className="timeframe-selector">
           <button
             className={timeframe === '24h' ? 'active' : ''}
             onClick={() => setTimeframe('24h')}
           >
             Last 24 Hours
           </button>
           <button
             className={timeframe === '7d' ? 'active' : ''}
             onClick={() => setTimeframe('7d')}
           >
             Last 7 Days
           </button>
           <button
             className={timeframe === '30d' ? 'active' : ''}
             onClick={() => setTimeframe('30d')}
           >
             Last 30 Days
           </button>
           <button
             className={timeframe === '90d' ? 'active' : ''}
             onClick={() => setTimeframe('90d')}
           >
             Last 90 Days
           </button>
         </div>
         
         <div className="analytics-grid">
           <div className="chart-container">
             <h2>Event Counts</h2>
             <ResponsiveContainer width="100%" height={300}>
               <BarChart data={eventCounts}>
                 <CartesianGrid strokeDasharray="3 3" />
                 <XAxis dataKey="name" />
                 <YAxis />
                 <Tooltip />
                 <Legend />
                 <Bar dataKey="count" fill="#8884d8" />
               </BarChart>
             </ResponsiveContainer>
           </div>
           
           <div className="chart-container">
             <h2>Page Views</h2>
             <ResponsiveContainer width="100%" height={300}>
               <PieChart>
                 <Pie
                   data={pageViews}
                   dataKey="count"
                   nameKey="path"
                   cx="50%"
                   cy="50%"
                   outerRadius={100}
                   fill="#82ca9d"
                   label
                 />
                 <Tooltip />
                 <Legend />
               </PieChart>
             </ResponsiveContainer>
           </div>
           
           <div className="chart-container">
             <h2>Daily Active Users</h2>
             <ResponsiveContainer width="100%" height={300}>
               <LineChart data={userActivity}>
                 <CartesianGrid strokeDasharray="3 3" />
                 <XAxis dataKey="date" />
                 <YAxis />
                 <Tooltip />
                 <Legend />
                 <Line type="monotone" dataKey="users" stroke="#8884d8" />
               </LineChart>
             </ResponsiveContainer>
           </div>
         </div>
       </div>
     );
   }
   ```

4. **Create Privacy Settings Component**
   ```typescript
   // packages/ui/src/analytics/PrivacySettings.tsx
   'use client';
   
   import { useState } from 'react';
   import { useAnalytics } from '@supa/shared';
   
   export function PrivacySettings() {
     const { preferences, updatePreferences, isLoading } = useAnalytics();
     const [isSaving, setIsSaving] = useState(false);
     const [formValues, setFormValues] = useState({
       allow_usage_tracking: preferences?.allow_usage_tracking || false,
       allow_error_reporting: preferences?.allow_error_reporting || false,
       anonymize_data: preferences?.anonymize_data || false,
     });
     
     const handleChange = (e) => {
       const { name, checked } = e.target;
       setFormValues((prev) => ({
         ...prev,
         [name]: checked,
       }));
     };
     
     const handleSubmit = async (e) => {
       e.preventDefault();
       setIsSaving(true);
       
       try {
         await updatePreferences(formValues);
       } catch (error) {
         console.error('Error updating privacy settings:', error);
       } finally {
         setIsSaving(false);
       }
     };
     
     if (isLoading) {
       return <div>Loading privacy settings...</div>;
     }
     
     return (
       <div className="privacy-settings">
         <h2>Privacy Settings</h2>
         <p>
           Control how your data is collected and used within the application.
         </p>
         
         <form onSubmit={handleSubmit}>
           <div className="form-group">
             <label>
               <input
                 type="checkbox"
                 name="allow_usage_tracking"
                 checked={formValues.allow_usage_tracking}
                 onChange={handleChange}
               />
               Allow usage tracking
             </label>
             <p className="help-text">
               We collect anonymous usage data to improve the application experience.
             </p>
           </div>
           
           <div className="form-group">
             <label>
               <input
                 type="checkbox"
                 name="allow_error_reporting"
                 checked={formValues.allow_error_reporting}
                 onChange={handleChange}
               />
               Allow error reporting
             </label>
             <p className="help-text">
               We collect error information to fix bugs and improve stability.
             </p>
           </div>
           
           <div className="form-group">
             <label>
               <input
                 type="checkbox"
                 name="anonymize_data"
                 checked={formValues.anonymize_data}
                 onChange={handleChange}
               />
               Anonymize my data
             </label>
             <p className="help-text">
               Remove personally identifiable information from collected data.
             </p>
           </div>
           
           <button type="submit" disabled={isSaving}>
             {isSaving ? 'Saving...' : 'Save Settings'}
           </button>
         </form>
       </div>
     );
   }
   ```

5. **Add Analytics Provider to App**
   ```typescript
   // apps/web/app/layout.tsx
   import { AnalyticsProvider } from '@supa/shared';
   
   export default function RootLayout({ children }) {
     return (
       <html lang="en">
         <body>
           <AnalyticsProvider>
             {children}
           </AnalyticsProvider>
         </body>
       </html>
     );
   }
   ```

6. **Add Privacy Settings to User Profile**
   ```typescript
   // apps/web/app/app/profile/page.tsx
   import { PrivacySettings } from '@supa/ui';
   
   export default function ProfilePage() {
     return (
       <div className="profile-page">
         {/* Other profile components */}
         
         <section className="privacy-section">
           <PrivacySettings />
         </section>
       </div>
     );
   }
   ```

## Privacy Considerations
- Implement clear opt-out mechanisms for all tracking
- Allow users to anonymize their data
- Provide transparent privacy policy explaining data usage
- Comply with GDPR, CCPA, and other relevant regulations
- Implement data retention policies
- Avoid tracking sensitive personal information

## Security Considerations
- Use RLS policies to restrict access to analytics data
- Encrypt sensitive data in transit and at rest
- Implement proper authentication for analytics dashboard
- Regularly audit analytics data access

## Testing
- Test tracking with various user preferences
- Verify opt-out functionality works correctly
- Test analytics dashboard with various data sets
- Test privacy settings UI

## Deployment Checklist
- Ensure database migrations are applied
- Verify RLS policies are working correctly
- Test the complete analytics flow in production
- Configure third-party analytics services (if used)
- Update privacy policy to reflect analytics practices
