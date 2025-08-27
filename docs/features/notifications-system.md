# Notifications System

## Overview
A comprehensive notifications system that delivers timely, relevant alerts to users across multiple channels (in-app, email, push) with preference management.

## Purpose
To keep users informed about important events, updates, and actions relevant to their account, enhancing engagement and providing critical information.

## Technical Implementation

### Database Schema
```sql
-- Create notifications table
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Create notification preferences table
create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email_enabled boolean not null default true,
  push_enabled boolean not null default true,
  in_app_enabled boolean not null default true,
  types jsonb default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Create notification templates table
create table if not exists public.notification_templates (
  type text primary key,
  title_template text not null,
  body_template text not null,
  channels jsonb not null default '["in_app", "email"]'::jsonb,
  data_schema jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add indexes
create index if not exists idx_notifications_user_id on public.notifications (user_id);
create index if not exists idx_notifications_created_at on public.notifications (created_at);
create index if not exists idx_notifications_is_read on public.notifications (is_read);

-- Add RLS policies
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_templates enable row level security;

-- Users can view their own notifications
create policy "Users can view their own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

-- Users can update their own notifications (e.g., mark as read)
create policy "Users can update their own notifications"
  on public.notifications for update
  using (auth.uid() = user_id);

-- Users can view their own notification preferences
create policy "Users can view their own notification preferences"
  on public.notification_preferences for select
  using (auth.uid() = user_id);

-- Users can update their own notification preferences
create policy "Users can update their own notification preferences"
  on public.notification_preferences for update
  using (auth.uid() = user_id);

-- Only admins can view notification templates
create policy "Admins can view notification templates"
  on public.notification_templates for select
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Only admins can update notification templates
create policy "Admins can update notification templates"
  on public.notification_templates for update
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));
```

### Required Packages
```bash
pnpm add handlebars expo-notifications @react-native-async-storage/async-storage react-native-push-notification @react-email/components nodemailer
```

### Implementation Steps

1. **Create Notification Service**
```typescript
// supabase/functions/notify/index.ts
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';
import * as Handlebars from 'https://esm.sh/handlebars@4.7.7';
import { SMTPClient } from 'https://deno.land/x/denomailer/mod.ts';

// Initialize Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Initialize SMTP client
const smtp = new SMTPClient({
  connection: {
    hostname: Deno.env.get('SMTP_HOST') ?? '',
    port: parseInt(Deno.env.get('SMTP_PORT') ?? '587'),
    tls: true,
    auth: {
      username: Deno.env.get('SMTP_USERNAME') ?? '',
      password: Deno.env.get('SMTP_PASSWORD') ?? '',
    },
  },
});

serve(async (req) => {
  try {
    const { method, body } = req;
    
    // Only allow POST requests
    if (method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    const { type, userId, data = {}, overrideChannels } = await req.json();
    
    // Validate required fields
    if (!type || !userId) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    // Get notification template
    const { data: template, error: templateError } = await supabase
      .from('notification_templates')
      .select('*')
      .eq('type', type)
      .single();
    
    if (templateError || !template) {
      return new Response(JSON.stringify({ error: 'Template not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    
    // Get user notification preferences
    const { data: preferences, error: preferencesError } = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .single();
    
    // If no preferences found, create default preferences
    let userPreferences = preferences;
    if (preferencesError) {
      const { data: newPreferences } = await supabase
        .from('notification_preferences')
        .insert({
          user_id: userId,
          email_enabled: true,
          push_enabled: true,
          in_app_enabled: true,
        })
        .select()
        .single();
      
      userPreferences = newPreferences;
    }
    
    // Compile templates
    const titleTemplate = Handlebars.compile(template.title_template);
    const bodyTemplate = Handlebars.compile(template.body_template);
    
    const title = titleTemplate(data);
    const body = bodyTemplate(data);
    
    // Determine channels to send notification
    const channels = overrideChannels || template.channels;
    
    // Create in-app notification
    if (channels.includes('in_app') && userPreferences.in_app_enabled) {
      await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          type,
          title,
          body,
          data,
        });
    }
    
    // Send email notification
    if (channels.includes('email') && userPreferences.email_enabled) {
      // Get user email
      const { data: user } = await supabase.auth.admin.getUserById(userId);
      
      if (user?.email) {
        await smtp.send({
          from: Deno.env.get('EMAIL_FROM') ?? 'notifications@example.com',
          to: user.email,
          subject: title,
          html: body,
        });
      }
    }
    
    // For push notifications, we store a record that the mobile app will poll
    if (channels.includes('push') && userPreferences.push_enabled) {
      await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          type,
          title,
          body,
          data: { ...data, _push_notification: true },
        });
    }
    
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
```

2. **Create Notification Client**
```typescript
// packages/shared/src/notifications/client.ts
import { createBrowserClient } from '@supabase/ssr';

// Send notification
export const sendNotification = async (
  type: string,
  userId: string,
  data: Record<string, any> = {},
  overrideChannels?: string[]
) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { error } = await supabase.functions.invoke('notify', {
      body: {
        type,
        userId,
        data,
        overrideChannels,
      },
    });
    
    if (error) throw error;
    
    return { success: true };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw error;
  }
};

// Get user notifications
export const getUserNotifications = async (limit = 20, offset = 0) => {
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
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error fetching notifications:', error);
    throw error;
  }
};

// Mark notification as read
export const markNotificationAsRead = async (notificationId: string) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId);
    
    if (error) throw error;
    
    return { success: true };
  } catch (error) {
    console.error('Error marking notification as read:', error);
    throw error;
  }
};

// Get notification preferences
export const getNotificationPreferences = async () => {
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
      .from('notification_preferences')
      .select('*')
      .eq('user_id', user.id)
      .single();
    
    if (error) {
      // Create default preferences if not found
      const { data: newPrefs } = await supabase
        .from('notification_preferences')
        .insert({
          user_id: user.id,
          email_enabled: true,
          push_enabled: true,
          in_app_enabled: true,
        })
        .select()
        .single();
      
      return newPrefs;
    }
    
    return data;
  } catch (error) {
    console.error('Error fetching notification preferences:', error);
    throw error;
  }
};

// Update notification preferences
export const updateNotificationPreferences = async (preferences: {
  email_enabled?: boolean;
  push_enabled?: boolean;
  in_app_enabled?: boolean;
  types?: Record<string, boolean>;
}) => {
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
      .from('notification_preferences')
      .update({
        ...preferences,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', user.id)
      .select();
    
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    throw error;
  }
};
```

3. **Create Notification Components**
```typescript
// packages/ui/src/notifications/NotificationBell.tsx
'use client';

import { useState, useEffect } from 'react';
import { getUserNotifications, markNotificationAsRead } from '@supa/shared';

export function NotificationBell() {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [isOpen, setIsOpen] = useState(false);
  
  useEffect(() => {
    // Load notifications
    const loadNotifications = async () => {
      try {
        const data = await getUserNotifications(10);
        setNotifications(data);
        setUnreadCount(data.filter(n => !n.is_read).length);
      } catch (error) {
        console.error('Error loading notifications:', error);
      }
    };
    
    loadNotifications();
    
    // Set up polling for new notifications
    const interval = setInterval(loadNotifications, 30000);
    
    return () => clearInterval(interval);
  }, []);
  
  const handleNotificationClick = async (notification) => {
    if (!notification.is_read) {
      try {
        await markNotificationAsRead(notification.id);
        
        // Update local state
        setNotifications(prev => 
          prev.map(n => 
            n.id === notification.id ? { ...n, is_read: true } : n
          )
        );
        setUnreadCount(prev => Math.max(0, prev - 1));
      } catch (error) {
        console.error('Error marking notification as read:', error);
      }
    }
    
    // Handle navigation or action based on notification type
    if (notification.data.url) {
      window.location.href = notification.data.url;
    }
  };
  
  return (
    <div className="notification-bell">
      <button 
        className="bell-button"
        onClick={() => setIsOpen(!isOpen)}
      >
        <span className="bell-icon">🔔</span>
        {unreadCount > 0 && (
          <span className="unread-badge">{unreadCount}</span>
        )}
      </button>
      
      {isOpen && (
        <div className="notification-dropdown">
          <div className="notification-header">
            <h3>Notifications</h3>
            {unreadCount > 0 && (
              <button 
                className="mark-all-read"
                onClick={async () => {
                  // Mark all as read
                  try {
                    for (const notification of notifications.filter(n => !n.is_read)) {
                      await markNotificationAsRead(notification.id);
                    }
                    
                    // Update local state
                    setNotifications(prev => 
                      prev.map(n => ({ ...n, is_read: true }))
                    );
                    setUnreadCount(0);
                  } catch (error) {
                    console.error('Error marking all as read:', error);
                  }
                }}
              >
                Mark all as read
              </button>
            )}
          </div>
          
          <div className="notification-list">
            {notifications.length === 0 ? (
              <div className="empty-state">
                No notifications
              </div>
            ) : (
              notifications.map(notification => (
                <div 
                  key={notification.id}
                  className={`notification-item ${notification.is_read ? '' : 'unread'}`}
                  onClick={() => handleNotificationClick(notification)}
                >
                  <div className="notification-title">{notification.title}</div>
                  <div className="notification-body">{notification.body}</div>
                  <div className="notification-time">
                    {new Date(notification.created_at).toLocaleString()}
                  </div>
                </div>
              ))
            )}
          </div>
          
          <div className="notification-footer">
            <a href="/app/notifications">View all notifications</a>
          </div>
        </div>
      )}
    </div>
  );
}
```

4. **Create Notification Preferences Component**
```typescript
// packages/ui/src/notifications/NotificationPreferences.tsx
'use client';

import { useState, useEffect } from 'react';
import { getNotificationPreferences, updateNotificationPreferences } from '@supa/shared';

export function NotificationPreferences() {
  const [preferences, setPreferences] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  
  useEffect(() => {
    async function loadPreferences() {
      try {
        const data = await getNotificationPreferences();
        setPreferences(data);
      } catch (error) {
        console.error('Error loading notification preferences:', error);
      } finally {
        setIsLoading(false);
      }
    }
    
    loadPreferences();
  }, []);
  
  const handleToggle = (key) => {
    setPreferences(prev => ({
      ...prev,
      [key]: !prev[key],
    }));
  };
  
  const handleSave = async () => {
    setIsSaving(true);
    
    try {
      await updateNotificationPreferences({
        email_enabled: preferences.email_enabled,
        push_enabled: preferences.push_enabled,
        in_app_enabled: preferences.in_app_enabled,
        types: preferences.types,
      });
    } catch (error) {
      console.error('Error saving notification preferences:', error);
    } finally {
      setIsSaving(false);
    }
  };
  
  if (isLoading) {
    return <div>Loading notification preferences...</div>;
  }
  
  return (
    <div className="notification-preferences">
      <h2>Notification Preferences</h2>
      
      <div className="preferences-section">
        <h3>Notification Channels</h3>
        
        <div className="preference-item">
          <label>
            <input
              type="checkbox"
              checked={preferences.in_app_enabled}
              onChange={() => handleToggle('in_app_enabled')}
            />
            In-app notifications
          </label>
        </div>
        
        <div className="preference-item">
          <label>
            <input
              type="checkbox"
              checked={preferences.email_enabled}
              onChange={() => handleToggle('email_enabled')}
            />
            Email notifications
          </label>
        </div>
        
        <div className="preference-item">
          <label>
            <input
              type="checkbox"
              checked={preferences.push_enabled}
              onChange={() => handleToggle('push_enabled')}
            />
            Push notifications
          </label>
        </div>
      </div>
      
      <button 
        className="save-button"
        onClick={handleSave}
        disabled={isSaving}
      >
        {isSaving ? 'Saving...' : 'Save Preferences'}
      </button>
    </div>
  );
}
```

5. **Create Mobile Push Notification Setup**
```typescript
// apps/mobile/src/notifications/setup.ts
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

// Configure notification handler
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

// Register for push notifications
export async function registerForPushNotifications() {
  try {
    // Check permissions
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;
    
    // Request permissions if not granted
    if (existingStatus !== 'granted') {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }
    
    if (finalStatus !== 'granted') {
      return false;
    }
    
    // Get push token
    const token = (await Notifications.getExpoPushTokenAsync()).data;
    
    // Store token in AsyncStorage
    await AsyncStorage.setItem('pushToken', token);
    
    // Configure for Android
    if (Platform.OS === 'android') {
      Notifications.setNotificationChannelAsync('default', {
        name: 'default',
        importance: Notifications.AndroidImportance.MAX,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: '#FF231F7C',
      });
    }
    
    return token;
  } catch (error) {
    console.error('Error registering for push notifications:', error);
    return false;
  }
}

// Set up notification listener
export function setupNotificationListener(onNotification) {
  const subscription = Notifications.addNotificationReceivedListener(onNotification);
  return subscription;
}

// Poll for push notifications
export async function pollForPushNotifications(supabaseUrl, supabaseKey, userId) {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    
    // Get unread push notifications
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .eq('is_read', false)
      .filter('data->_push_notification', 'eq', true);
    
    if (error) throw error;
    
    // Schedule local notifications for each push notification
    if (data && data.length > 0) {
      for (const notification of data) {
        await Notifications.scheduleNotificationAsync({
          content: {
            title: notification.title,
            body: notification.body,
            data: notification.data,
          },
          trigger: null, // Show immediately
        });
        
        // Mark as read
        await supabase
          .from('notifications')
          .update({ is_read: true })
          .eq('id', notification.id);
      }
    }
  } catch (error) {
    console.error('Error polling for push notifications:', error);
  }
}
```

6. **Create Admin Notification Template Manager**
```typescript
// apps/web/app/admin/notifications/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { createPublicClient } from '@supa/supabase';

export default function NotificationTemplates() {
  const [templates, setTemplates] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [currentTemplate, setCurrentTemplate] = useState(null);
  
  useEffect(() => {
    async function loadTemplates() {
      try {
        const supabase = createPublicClient();
        const { data, error } = await supabase
          .from('notification_templates')
          .select('*')
          .order('type');
        
        if (error) throw error;
        
        setTemplates(data || []);
      } catch (error) {
        console.error('Error loading templates:', error);
      } finally {
        setIsLoading(false);
      }
    }
    
    loadTemplates();
  }, []);
  
  const handleSaveTemplate = async () => {
    try {
      const supabase = createPublicClient();
      
      const { error } = await supabase
        .from('notification_templates')
        .upsert({
          ...currentTemplate,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'type',
        });
      
      if (error) throw error;
      
      // Refresh templates
      const { data } = await supabase
        .from('notification_templates')
        .select('*')
        .order('type');
      
      setTemplates(data || []);
      setCurrentTemplate(null);
    } catch (error) {
      console.error('Error saving template:', error);
    }
  };
  
  if (isLoading) {
    return <div>Loading notification templates...</div>;
  }
  
  return (
    <div className="notification-templates">
      <h1>Notification Templates</h1>
      
      <div className="templates-grid">
        <div className="templates-list">
          <button 
            className="new-template-button"
            onClick={() => setCurrentTemplate({
              type: '',
              title_template: '',
              body_template: '',
              channels: ['in_app', 'email'],
              data_schema: {},
            })}
          >
            New Template
          </button>
          
          {templates.map(template => (
            <div 
              key={template.type}
              className={`template-item ${currentTemplate?.type === template.type ? 'active' : ''}`}
              onClick={() => setCurrentTemplate(template)}
            >
              <div className="template-type">{template.type}</div>
              <div className="template-channels">
                {template.channels.join(', ')}
              </div>
            </div>
          ))}
        </div>
        
        {currentTemplate && (
          <div className="template-editor">
            <div className="form-group">
              <label>Type</label>
              <input
                type="text"
                value={currentTemplate.type}
                onChange={(e) => setCurrentTemplate({
                  ...currentTemplate,
                  type: e.target.value,
                })}
              />
            </div>
            
            <div className="form-group">
              <label>Title Template</label>
              <input
                type="text"
                value={currentTemplate.title_template}
                onChange={(e) => setCurrentTemplate({
                  ...currentTemplate,
                  title_template: e.target.value,
                })}
              />
              <p className="help-text">
                Use Handlebars syntax: {{variable_name}}
              </p>
            </div>
            
            <div className="form-group">
              <label>Body Template</label>
              <textarea
                value={currentTemplate.body_template}
                onChange={(e) => setCurrentTemplate({
                  ...currentTemplate,
                  body_template: e.target.value,
                })}
                rows={5}
              />
              <p className="help-text">
                Use Handlebars syntax: {{variable_name}}
              </p>
            </div>
            
            <div className="form-group">
              <label>Channels</label>
              <div className="checkbox-group">
                {['in_app', 'email', 'push'].map(channel => (
                  <label key={channel}>
                    <input
                      type="checkbox"
                      checked={currentTemplate.channels.includes(channel)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setCurrentTemplate({
                            ...currentTemplate,
                            channels: [...currentTemplate.channels, channel],
                          });
                        } else {
                          setCurrentTemplate({
                            ...currentTemplate,
                            channels: currentTemplate.channels.filter(c => c !== channel),
                          });
                        }
                      }}
                    />
                    {channel}
                  </label>
                ))}
              </div>
            </div>
            
            <div className="button-group">
              <button 
                className="cancel-button"
                onClick={() => setCurrentTemplate(null)}
              >
                Cancel
              </button>
              <button 
                className="save-button"
                onClick={handleSaveTemplate}
              >
                Save Template
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
```

## Security Considerations
- Implement rate limiting for notification sending
- Validate notification templates to prevent injection attacks
- Use RLS policies to protect notification data
- Sanitize user input in notification content
- Implement proper authentication for notification endpoints

## User Experience Considerations
- Provide clear notification preferences
- Group similar notifications to prevent overwhelming users
- Use appropriate notification channels based on urgency
- Allow users to easily dismiss or mark notifications as read
- Implement badge counts for unread notifications

## Testing
- Test notification delivery across all channels
- Test notification preferences
- Test template rendering with various data inputs
- Test push notification delivery on different devices
- Test notification polling and real-time updates

## Deployment Checklist
- Set up SMTP server for email notifications
- Configure push notification services
- Create initial notification templates
- Test notification flow in production
- Monitor notification delivery and open rates
