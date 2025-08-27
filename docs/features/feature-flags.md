# Feature Flags

## Overview
A flexible feature flag system that enables controlled rollout of features to specific users, environments, or percentages of traffic.

## Purpose
To safely deploy features, conduct A/B testing, manage feature lifecycles, and provide customized experiences to different user segments.

## Technical Implementation

### Database Schema
```sql
-- Create feature flags table
create table if not exists public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  is_enabled boolean not null default false,
  type text not null check (type in ('boolean', 'percentage', 'user_group', 'environment')),
  rules jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create user feature overrides table
create table if not exists public.user_feature_overrides (
  user_id uuid not null references auth.users(id) on delete cascade,
  feature_key text not null references public.feature_flags(key) on delete cascade,
  is_enabled boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, feature_key)
);

-- Create feature flag history table for auditing
create table if not exists public.feature_flag_history (
  id uuid primary key default gen_random_uuid(),
  feature_key text not null references public.feature_flags(key) on delete cascade,
  action text not null,
  previous_state jsonb,
  new_state jsonb,
  performed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Add indexes
create index if not exists idx_feature_flags_key on public.feature_flags (key);
create index if not exists idx_feature_flag_history_feature_key on public.feature_flag_history (feature_key);

-- Add RLS policies
alter table public.feature_flags enable row level security;
alter table public.user_feature_overrides enable row level security;
alter table public.feature_flag_history enable row level security;

-- Everyone can view feature flags
create policy "Everyone can view feature flags"
  on public.feature_flags for select
  using (true);

-- Only admins can modify feature flags
create policy "Admins can modify feature flags"
  on public.feature_flags for all
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Users can view their own feature overrides
create policy "Users can view their own feature overrides"
  on public.user_feature_overrides for select
  using (auth.uid() = user_id);

-- Only admins can modify user feature overrides
create policy "Admins can modify user feature overrides"
  on public.user_feature_overrides for all
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Only admins can view feature flag history
create policy "Admins can view feature flag history"
  on public.feature_flag_history for select
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));
```

### Required Packages
```bash
pnpm add zustand nanoid
```

### Implementation Steps

1. **Create Feature Flag Service**
```typescript
// packages/shared/src/feature-flags/service.ts
import { createBrowserClient } from '@supabase/ssr';

// Get feature flag state
export const getFeatureFlag = async (key: string) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    // Check for user-specific override
    const { data: { user } } = await supabase.auth.getUser();
    
    if (user) {
      const { data: override } = await supabase
        .from('user_feature_overrides')
        .select('is_enabled')
        .eq('user_id', user.id)
        .eq('feature_key', key)
        .single();
      
      if (override) {
        return override.is_enabled;
      }
    }
    
    // Get feature flag
    const { data: flag, error } = await supabase
      .from('feature_flags')
      .select('*')
      .eq('key', key)
      .single();
    
    if (error || !flag) {
      return false;
    }
    
    // If flag is disabled, return false
    if (!flag.is_enabled) {
      return false;
    }
    
    // Check rules based on flag type
    switch (flag.type) {
      case 'boolean':
        return flag.is_enabled;
        
      case 'percentage':
        const percentage = flag.rules.percentage || 0;
        return Math.random() * 100 < percentage;
        
      case 'user_group':
        if (!user) return false;
        
        const userGroups = flag.rules.groups || [];
        const { data: userProfile } = await supabase
          .from('user_profiles')
          .select('role, subscription_tier')
          .eq('id', user.id)
          .single();
          
        if (!userProfile) return false;
        
        return userGroups.includes(userProfile.role) || 
               userGroups.includes(userProfile.subscription_tier);
        
      case 'environment':
        const environments = flag.rules.environments || [];
        const currentEnv = process.env.NEXT_PUBLIC_APP_ENV || 'development';
        return environments.includes(currentEnv);
        
      default:
        return false;
    }
  } catch (error) {
    console.error(`Error getting feature flag ${key}:`, error);
    return false;
  }
};

// Get all feature flags
export const getAllFeatureFlags = async () => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { data, error } = await supabase
      .from('feature_flags')
      .select('*')
      .order('name');
    
    if (error) throw error;
    
    return data || [];
  } catch (error) {
    console.error('Error getting all feature flags:', error);
    return [];
  }
};

// Create or update feature flag
export const upsertFeatureFlag = async (flag) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    // Get previous state for history
    let previousState = null;
    if (flag.key) {
      const { data } = await supabase
        .from('feature_flags')
        .select('*')
        .eq('key', flag.key)
        .single();
      
      previousState = data;
    }
    
    // Update or create flag
    const { data, error } = await supabase
      .from('feature_flags')
      .upsert({
        ...flag,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'key',
      })
      .select()
      .single();
    
    if (error) throw error;
    
    // Record history
    const { data: { user } } = await supabase.auth.getUser();
    
    if (user) {
      await supabase
        .from('feature_flag_history')
        .insert({
          feature_key: data.key,
          action: previousState ? 'update' : 'create',
          previous_state: previousState,
          new_state: data,
          performed_by: user.id,
        });
    }
    
    return data;
  } catch (error) {
    console.error('Error upserting feature flag:', error);
    throw error;
  }
};

// Set user override
export const setUserFeatureOverride = async (userId: string, featureKey: string, isEnabled: boolean) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { error } = await supabase
      .from('user_feature_overrides')
      .upsert({
        user_id: userId,
        feature_key: featureKey,
        is_enabled: isEnabled,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,feature_key',
      });
    
    if (error) throw error;
    
    return { success: true };
  } catch (error) {
    console.error('Error setting user feature override:', error);
    throw error;
  }
};
```

2. **Create Feature Flag Store**
```typescript
// packages/shared/src/feature-flags/store.ts
import { create } from 'zustand';
import { getFeatureFlag } from './service';

interface FeatureFlagState {
  flags: Record<string, boolean>;
  isLoading: Record<string, boolean>;
  checkFlag: (key: string) => Promise<boolean>;
  setFlag: (key: string, value: boolean) => void;
}

export const useFeatureFlags = create<FeatureFlagState>((set, get) => ({
  flags: {},
  isLoading: {},
  
  checkFlag: async (key: string) => {
    // Return cached value if available
    if (get().flags[key] !== undefined) {
      return get().flags[key];
    }
    
    // Set loading state
    set(state => ({
      isLoading: { ...state.isLoading, [key]: true },
    }));
    
    try {
      // Get flag value
      const isEnabled = await getFeatureFlag(key);
      
      // Update state
      set(state => ({
        flags: { ...state.flags, [key]: isEnabled },
        isLoading: { ...state.isLoading, [key]: false },
      }));
      
      return isEnabled;
    } catch (error) {
      console.error(`Error checking feature flag ${key}:`, error);
      
      // Update state with default (false)
      set(state => ({
        flags: { ...state.flags, [key]: false },
        isLoading: { ...state.isLoading, [key]: false },
      }));
      
      return false;
    }
  },
  
  setFlag: (key: string, value: boolean) => {
    set(state => ({
      flags: { ...state.flags, [key]: value },
    }));
  },
}));
```

3. **Create Feature Flag Hook**
```typescript
// packages/shared/src/feature-flags/hooks.ts
import { useState, useEffect } from 'react';
import { useFeatureFlags } from './store';

export function useFeatureFlag(key: string, defaultValue: boolean = false) {
  const { flags, isLoading, checkFlag } = useFeatureFlags();
  const [isEnabled, setIsEnabled] = useState(flags[key] ?? defaultValue);
  
  useEffect(() => {
    let isMounted = true;
    
    const loadFlag = async () => {
      const value = await checkFlag(key);
      if (isMounted) {
        setIsEnabled(value);
      }
    };
    
    if (flags[key] === undefined) {
      loadFlag();
    } else {
      setIsEnabled(flags[key]);
    }
    
    return () => {
      isMounted = false;
    };
  }, [key, checkFlag, flags]);
  
  return {
    isEnabled,
    isLoading: isLoading[key] ?? false,
  };
}
```

4. **Create Feature Flag Components**
```typescript
// packages/ui/src/feature-flags/FeatureFlag.tsx
'use client';

import { ReactNode } from 'react';
import { useFeatureFlag } from '@supa/shared';

interface FeatureFlagProps {
  flag: string;
  children: ReactNode;
  fallback?: ReactNode;
}

export function FeatureFlag({ flag, children, fallback = null }: FeatureFlagProps) {
  const { isEnabled } = useFeatureFlag(flag);
  
  return isEnabled ? <>{children}</> : <>{fallback}</>;
}
```

5. **Create Feature Flag Admin UI**
```typescript
// apps/web/app/admin/feature-flags/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { nanoid } from 'nanoid';
import { getAllFeatureFlags, upsertFeatureFlag } from '@supa/shared';

export default function FeatureFlagAdmin() {
  const [flags, setFlags] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [editingFlag, setEditingFlag] = useState(null);
  
  useEffect(() => {
    const loadFlags = async () => {
      try {
        const data = await getAllFeatureFlags();
        setFlags(data);
      } catch (error) {
        console.error('Error loading feature flags:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    loadFlags();
  }, []);
  
  const handleSaveFlag = async () => {
    try {
      // Generate key if new flag
      if (!editingFlag.key) {
        editingFlag.key = nanoid(8);
      }
      
      const savedFlag = await upsertFeatureFlag(editingFlag);
      
      // Update flags list
      setFlags(prev => {
        const index = prev.findIndex(f => f.key === savedFlag.key);
        if (index >= 0) {
          return [...prev.slice(0, index), savedFlag, ...prev.slice(index + 1)];
        } else {
          return [...prev, savedFlag];
        }
      });
      
      setEditingFlag(null);
    } catch (error) {
      console.error('Error saving feature flag:', error);
    }
  };
  
  const toggleFlag = async (flag) => {
    try {
      const updatedFlag = {
        ...flag,
        is_enabled: !flag.is_enabled,
      };
      
      const savedFlag = await upsertFeatureFlag(updatedFlag);
      
      // Update flags list
      setFlags(prev => {
        const index = prev.findIndex(f => f.key === savedFlag.key);
        return [...prev.slice(0, index), savedFlag, ...prev.slice(index + 1)];
      });
    } catch (error) {
      console.error('Error toggling feature flag:', error);
    }
  };
  
  if (isLoading) {
    return <div>Loading feature flags...</div>;
  }
  
  return (
    <div className="feature-flag-admin">
      <h1>Feature Flags</h1>
      
      <button
        className="new-flag-button"
        onClick={() => setEditingFlag({
          name: '',
          description: '',
          is_enabled: false,
          type: 'boolean',
          rules: {},
        })}
      >
        New Feature Flag
      </button>
      
      <div className="flags-table">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Key</th>
              <th>Type</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {flags.map(flag => (
              <tr key={flag.key}>
                <td>{flag.name}</td>
                <td>{flag.key}</td>
                <td>{flag.type}</td>
                <td>
                  <span className={`status ${flag.is_enabled ? 'enabled' : 'disabled'}`}>
                    {flag.is_enabled ? 'Enabled' : 'Disabled'}
                  </span>
                </td>
                <td>
                  <button
                    className="toggle-button"
                    onClick={() => toggleFlag(flag)}
                  >
                    {flag.is_enabled ? 'Disable' : 'Enable'}
                  </button>
                  <button
                    className="edit-button"
                    onClick={() => setEditingFlag(flag)}
                  >
                    Edit
                  </button>
                </td>
              </tr>
            ))}
            {flags.length === 0 && (
              <tr>
                <td colSpan={5}>No feature flags found</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      
      {editingFlag && (
        <div className="flag-editor-modal">
          <div className="flag-editor">
            <h2>{editingFlag.key ? 'Edit Feature Flag' : 'New Feature Flag'}</h2>
            
            <div className="form-group">
              <label>Name:</label>
              <input
                type="text"
                value={editingFlag.name}
                onChange={(e) => setEditingFlag({
                  ...editingFlag,
                  name: e.target.value,
                })}
              />
            </div>
            
            <div className="form-group">
              <label>Description:</label>
              <textarea
                value={editingFlag.description || ''}
                onChange={(e) => setEditingFlag({
                  ...editingFlag,
                  description: e.target.value,
                })}
                rows={3}
              />
            </div>
            
            <div className="form-group">
              <label>Type:</label>
              <select
                value={editingFlag.type}
                onChange={(e) => setEditingFlag({
                  ...editingFlag,
                  type: e.target.value,
                  rules: {}, // Reset rules when type changes
                })}
              >
                <option value="boolean">Boolean</option>
                <option value="percentage">Percentage Rollout</option>
                <option value="user_group">User Group</option>
                <option value="environment">Environment</option>
              </select>
            </div>
            
            {editingFlag.type === 'percentage' && (
              <div className="form-group">
                <label>Percentage (0-100):</label>
                <input
                  type="number"
                  min="0"
                  max="100"
                  value={editingFlag.rules.percentage || 0}
                  onChange={(e) => setEditingFlag({
                    ...editingFlag,
                    rules: {
                      ...editingFlag.rules,
                      percentage: parseInt(e.target.value, 10),
                    },
                  })}
                />
              </div>
            )}
            
            {editingFlag.type === 'user_group' && (
              <div className="form-group">
                <label>User Groups (comma separated):</label>
                <input
                  type="text"
                  value={(editingFlag.rules.groups || []).join(', ')}
                  onChange={(e) => setEditingFlag({
                    ...editingFlag,
                    rules: {
                      ...editingFlag.rules,
                      groups: e.target.value.split(',').map(g => g.trim()).filter(Boolean),
                    },
                  })}
                />
              </div>
            )}
            
            {editingFlag.type === 'environment' && (
              <div className="form-group">
                <label>Environments:</label>
                <div className="checkbox-group">
                  {['development', 'staging', 'production'].map(env => (
                    <label key={env}>
                      <input
                        type="checkbox"
                        checked={(editingFlag.rules.environments || []).includes(env)}
                        onChange={(e) => {
                          const environments = editingFlag.rules.environments || [];
                          if (e.target.checked) {
                            setEditingFlag({
                              ...editingFlag,
                              rules: {
                                ...editingFlag.rules,
                                environments: [...environments, env],
                              },
                            });
                          } else {
                            setEditingFlag({
                              ...editingFlag,
                              rules: {
                                ...editingFlag.rules,
                                environments: environments.filter(e => e !== env),
                              },
                            });
                          }
                        }}
                      />
                      {env}
                    </label>
                  ))}
                </div>
              </div>
            )}
            
            <div className="form-group">
              <label>Status:</label>
              <div className="toggle-switch">
                <input
                  type="checkbox"
                  id="flag-status"
                  checked={editingFlag.is_enabled}
                  onChange={(e) => setEditingFlag({
                    ...editingFlag,
                    is_enabled: e.target.checked,
                  })}
                />
                <label htmlFor="flag-status">
                  {editingFlag.is_enabled ? 'Enabled' : 'Disabled'}
                </label>
              </div>
            </div>
            
            <div className="button-group">
              <button
                className="cancel-button"
                onClick={() => setEditingFlag(null)}
              >
                Cancel
              </button>
              <button
                className="save-button"
                onClick={handleSaveFlag}
                disabled={!editingFlag.name}
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
```

6. **Usage Examples**

Example 1: Conditional rendering with Feature Flag component
```tsx
// apps/web/app/some-page.tsx
import { FeatureFlag } from '@supa/ui';

export default function SomePage() {
  return (
    <div>
      <h1>My Page</h1>
      
      <FeatureFlag flag="new_dashboard">
        <NewDashboard />
      </FeatureFlag>
      
      <FeatureFlag flag="beta_feature" fallback={<LegacyFeature />}>
        <BetaFeature />
      </FeatureFlag>
    </div>
  );
}
```

Example 2: Using the hook directly
```tsx
// apps/mobile/app/screens/HomeScreen.tsx
import { useFeatureFlag } from '@supa/shared';

export default function HomeScreen() {
  const { isEnabled: showNewUI } = useFeatureFlag('mobile_new_ui');
  
  return (
    <View>
      {showNewUI ? (
        <NewHomeLayout />
      ) : (
        <LegacyHomeLayout />
      )}
    </View>
  );
}
```

Example 3: Server-side feature flag check
```typescript
// apps/web/app/api/some-endpoint/route.ts
import { getFeatureFlag } from '@supa/shared';

export async function GET(request) {
  // Check if feature is enabled
  const isFeatureEnabled = await getFeatureFlag('api_v2');
  
  if (isFeatureEnabled) {
    return Response.json({ version: 'v2', data: {} });
  } else {
    return Response.json({ version: 'v1', data: {} });
  }
}
```

## Feature Flag Types

1. **Boolean Flags**
   - Simple on/off toggles
   - Used for enabling/disabling features globally

2. **Percentage Rollouts**
   - Gradually roll out features to a percentage of users
   - Useful for testing performance impact or gradual adoption

3. **User Group Targeting**
   - Enable features for specific user groups or subscription tiers
   - Examples: premium users, beta testers, internal staff

4. **Environment-based Flags**
   - Different flag states per environment
   - Examples: development, staging, production

## Security Considerations
- Implement proper RLS policies to prevent unauthorized flag changes
- Log all feature flag changes for audit purposes
- Validate flag rules to prevent injection attacks
- Ensure sensitive features have appropriate access controls

## Testing
- Test feature flag evaluation logic
- Test UI components with flags enabled and disabled
- Test percentage rollout distribution
- Test user group targeting
- Test environment-specific behavior

## Deployment Checklist
- Ensure database migrations are applied
- Verify RLS policies are working correctly
- Create initial feature flags
- Test feature flag evaluation in production
- Monitor feature flag usage and impact
