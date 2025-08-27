# Multi-language Support

## Overview
A comprehensive internationalization (i18n) system that enables the application to support multiple languages, locales, and regional formatting preferences.

## Purpose
To make the application accessible to a global audience by providing content in users' preferred languages and respecting regional formatting conventions.

## Technical Implementation

### Database Schema
```sql
-- Create languages table
create table if not exists public.languages (
  code text primary key,
  name text not null,
  native_name text not null,
  is_default boolean not null default false,
  is_enabled boolean not null default true,
  direction text not null default 'ltr',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create user language preferences
create table if not exists public.user_language_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  language_code text not null references public.languages(code) on delete restrict,
  updated_at timestamptz not null default now()
);

-- Create translations table
create table if not exists public.translations (
  id uuid primary key default gen_random_uuid(),
  namespace text not null,
  key text not null,
  language_code text not null references public.languages(code) on delete cascade,
  value text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (namespace, key, language_code)
);

-- Add indexes
create index if not exists idx_translations_namespace_key on public.translations (namespace, key);
create index if not exists idx_translations_language_code on public.translations (language_code);

-- Add RLS policies
alter table public.languages enable row level security;
alter table public.user_language_preferences enable row level security;
alter table public.translations enable row level security;

-- Everyone can view languages
create policy "Everyone can view languages"
  on public.languages for select
  using (true);

-- Users can view their own language preferences
create policy "Users can view their own language preferences"
  on public.user_language_preferences for select
  using (auth.uid() = user_id);

-- Users can update their own language preferences
create policy "Users can update their own language preferences"
  on public.user_language_preferences for update
  using (auth.uid() = user_id);

-- Everyone can view translations
create policy "Everyone can view translations"
  on public.translations for select
  using (true);

-- Only admins can update translations
create policy "Admins can update translations"
  on public.translations for update
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));

-- Insert default languages
insert into public.languages (code, name, native_name, is_default, is_enabled, direction)
values
  ('en', 'English', 'English', true, true, 'ltr'),
  ('es', 'Spanish', 'Español', false, true, 'ltr'),
  ('fr', 'French', 'Français', false, true, 'ltr'),
  ('de', 'German', 'Deutsch', false, true, 'ltr'),
  ('ar', 'Arabic', 'العربية', false, true, 'rtl'),
  ('zh', 'Chinese', '中文', false, true, 'ltr'),
  ('ja', 'Japanese', '日本語', false, true, 'ltr')
on conflict (code) do nothing;
```

### Required Packages
```bash
pnpm add next-intl i18next react-i18next i18next-browser-languagedetector i18next-http-backend date-fns-tz
```

### Implementation Steps

1. **Create i18n Configuration**
```typescript
// packages/shared/src/i18n/config.ts
import { createBrowserClient } from '@supabase/ssr';

// Default language
export const DEFAULT_LANGUAGE = 'en';

// Available languages
export const AVAILABLE_LANGUAGES = [
  { code: 'en', name: 'English', native: 'English', direction: 'ltr' },
  { code: 'es', name: 'Spanish', native: 'Español', direction: 'ltr' },
  { code: 'fr', name: 'French', native: 'Français', direction: 'ltr' },
  { code: 'de', name: 'German', native: 'Deutsch', direction: 'ltr' },
  { code: 'ar', name: 'Arabic', native: 'العربية', direction: 'rtl' },
  { code: 'zh', name: 'Chinese', native: '中文', direction: 'ltr' },
  { code: 'ja', name: 'Japanese', native: '日本語', direction: 'ltr' },
];

// Get user's language preference
export const getUserLanguage = async () => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { data: { user } } = await supabase.auth.getUser();
    
    if (!user) {
      return getBrowserLanguage();
    }
    
    const { data, error } = await supabase
      .from('user_language_preferences')
      .select('language_code')
      .eq('user_id', user.id)
      .single();
    
    if (error || !data) {
      return getBrowserLanguage();
    }
    
    return data.language_code;
  } catch (error) {
    console.error('Error getting user language:', error);
    return getBrowserLanguage();
  }
};

// Get browser language
export const getBrowserLanguage = () => {
  if (typeof navigator === 'undefined') {
    return DEFAULT_LANGUAGE;
  }
  
  const browserLang = navigator.language.split('-')[0];
  
  // Check if browser language is supported
  const isSupported = AVAILABLE_LANGUAGES.some(lang => lang.code === browserLang);
  
  return isSupported ? browserLang : DEFAULT_LANGUAGE;
};

// Set user's language preference
export const setUserLanguage = async (languageCode: string) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { data: { user } } = await supabase.auth.getUser();
    
    if (!user) {
      throw new Error('User not authenticated');
    }
    
    const { error } = await supabase
      .from('user_language_preferences')
      .upsert({
        user_id: user.id,
        language_code: languageCode,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
      });
    
    if (error) {
      throw error;
    }
    
    return { success: true };
  } catch (error) {
    console.error('Error setting user language:', error);
    throw error;
  }
};

// Load translations from database
export const loadTranslations = async (
  languageCode: string,
  namespace: string = 'common'
) => {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { data, error } = await supabase
      .from('translations')
      .select('key, value')
      .eq('language_code', languageCode)
      .eq('namespace', namespace);
    
    if (error) {
      throw error;
    }
    
    // Convert to key-value object
    const translations = data.reduce((acc, { key, value }) => {
      acc[key] = value;
      return acc;
    }, {});
    
    return translations;
  } catch (error) {
    console.error(`Error loading translations for ${languageCode}/${namespace}:`, error);
    return {};
  }
};
```

2. **Create i18n Client for Next.js**
```typescript
// apps/web/i18n.ts
import { notFound } from 'next/navigation';
import { getRequestConfig } from 'next-intl/server';
import { loadTranslations, DEFAULT_LANGUAGE } from '@supa/shared';

// Define locales
export const locales = ['en', 'es', 'fr', 'de', 'ar', 'zh', 'ja'];

// Get messages for locale
export default getRequestConfig(async ({ locale }) => {
  // Validate that the locale is configured
  if (!locales.includes(locale as any)) {
    notFound();
  }
  
  // Load translations from database
  const messages = await loadTranslations(locale);
  
  return {
    messages,
    timeZone: 'UTC',
    now: new Date(),
  };
});
```

3. **Configure Next.js Middleware**
```typescript
// apps/web/middleware.ts
import createMiddleware from 'next-intl/middleware';
import { locales } from './i18n';

export default createMiddleware({
  // A list of all locales that are supported
  locales,
  
  // If this locale is matched, pathnames work without a prefix (e.g. `/about`)
  defaultLocale: 'en',
  
  // Detect locale from Accept-Language header
  localeDetection: true,
});

export const config = {
  // Skip all paths that should not be internationalized
  matcher: ['/((?!api|_next|.*\\..*).*)'],
};
```

4. **Create Language Provider**
```typescript
// packages/shared/src/i18n/provider.tsx
'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { getUserLanguage, setUserLanguage, AVAILABLE_LANGUAGES } from './config';

interface LanguageContextType {
  currentLanguage: string;
  availableLanguages: typeof AVAILABLE_LANGUAGES;
  changeLanguage: (languageCode: string) => Promise<void>;
  isLoading: boolean;
}

const LanguageContext = createContext<LanguageContextType>({
  currentLanguage: 'en',
  availableLanguages: AVAILABLE_LANGUAGES,
  changeLanguage: async () => {},
  isLoading: true,
});

export const useLanguage = () => useContext(LanguageContext);

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [currentLanguage, setCurrentLanguage] = useState('en');
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();
  const pathname = usePathname();
  
  useEffect(() => {
    const loadLanguage = async () => {
      try {
        const lang = await getUserLanguage();
        setCurrentLanguage(lang);
      } catch (error) {
        console.error('Error loading language:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    loadLanguage();
  }, []);
  
  const changeLanguage = async (languageCode: string) => {
    try {
      // Save user preference
      await setUserLanguage(languageCode);
      
      // Update state
      setCurrentLanguage(languageCode);
      
      // Navigate to the same page with new locale
      const currentPathname = pathname || '/';
      
      // Extract locale from pathname
      const pathnameWithoutLocale = currentPathname
        .split('/')
        .slice(2)
        .join('/');
      
      // Navigate to new locale path
      router.push(`/${languageCode}/${pathnameWithoutLocale}`);
    } catch (error) {
      console.error('Error changing language:', error);
    }
  };
  
  return (
    <LanguageContext.Provider
      value={{
        currentLanguage,
        availableLanguages: AVAILABLE_LANGUAGES,
        changeLanguage,
        isLoading,
      }}
    >
      {children}
    </LanguageContext.Provider>
  );
}
```

5. **Create Language Selector Component**
```typescript
// packages/ui/src/i18n/LanguageSelector.tsx
'use client';

import { useState } from 'react';
import { useLanguage } from '@supa/shared';

export function LanguageSelector() {
  const { currentLanguage, availableLanguages, changeLanguage, isLoading } = useLanguage();
  const [isOpen, setIsOpen] = useState(false);
  
  if (isLoading) {
    return <div>Loading...</div>;
  }
  
  const currentLang = availableLanguages.find(lang => lang.code === currentLanguage);
  
  return (
    <div className="language-selector">
      <button
        className="language-button"
        onClick={() => setIsOpen(!isOpen)}
      >
        {currentLang?.native || 'English'}
      </button>
      
      {isOpen && (
        <div className="language-dropdown">
          {availableLanguages.map(language => (
            <button
              key={language.code}
              className={`language-option ${language.code === currentLanguage ? 'active' : ''}`}
              onClick={() => {
                changeLanguage(language.code);
                setIsOpen(false);
              }}
            >
              <span className="native-name">{language.native}</span>
              <span className="language-name">{language.name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
```

6. **Create Translation Management Component**
```typescript
// apps/web/app/admin/translations/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { createPublicClient } from '@supa/supabase';

export default function TranslationManager() {
  const [languages, setLanguages] = useState([]);
  const [namespaces, setNamespaces] = useState(['common', 'auth', 'dashboard']);
  const [translations, setTranslations] = useState([]);
  const [selectedLanguage, setSelectedLanguage] = useState('');
  const [selectedNamespace, setSelectedNamespace] = useState('common');
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [editingTranslation, setEditingTranslation] = useState(null);
  
  useEffect(() => {
    // Load languages
    const loadLanguages = async () => {
      try {
        const supabase = createPublicClient();
        const { data, error } = await supabase
          .from('languages')
          .select('*')
          .order('is_default', { ascending: false })
          .order('name');
        
        if (error) throw error;
        
        setLanguages(data || []);
        
        // Set default selected language
        if (data && data.length > 0) {
          const defaultLang = data.find(lang => lang.is_default) || data[0];
          setSelectedLanguage(defaultLang.code);
        }
      } catch (error) {
        console.error('Error loading languages:', error);
      }
    };
    
    // Load namespaces
    const loadNamespaces = async () => {
      try {
        const supabase = createPublicClient();
        const { data, error } = await supabase
          .from('translations')
          .select('namespace')
          .distinct();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          setNamespaces([...new Set(data.map(item => item.namespace))]);
        }
      } catch (error) {
        console.error('Error loading namespaces:', error);
      }
    };
    
    Promise.all([loadLanguages(), loadNamespaces()])
      .finally(() => setIsLoading(false));
  }, []);
  
  // Load translations when language or namespace changes
  useEffect(() => {
    if (!selectedLanguage || !selectedNamespace) {
      return;
    }
    
    const loadTranslations = async () => {
      setIsLoading(true);
      
      try {
        const supabase = createPublicClient();
        const { data, error } = await supabase
          .from('translations')
          .select('*')
          .eq('language_code', selectedLanguage)
          .eq('namespace', selectedNamespace)
          .order('key');
        
        if (error) throw error;
        
        setTranslations(data || []);
      } catch (error) {
        console.error('Error loading translations:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    loadTranslations();
  }, [selectedLanguage, selectedNamespace]);
  
  // Filter translations by search query
  const filteredTranslations = searchQuery
    ? translations.filter(
        t => t.key.toLowerCase().includes(searchQuery.toLowerCase()) ||
             t.value.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : translations;
  
  // Save translation
  const saveTranslation = async (translation) => {
    try {
      const supabase = createPublicClient();
      const { error } = await supabase
        .from('translations')
        .upsert({
          ...translation,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'namespace,key,language_code',
        });
      
      if (error) throw error;
      
      // Refresh translations
      const { data } = await supabase
        .from('translations')
        .select('*')
        .eq('language_code', selectedLanguage)
        .eq('namespace', selectedNamespace)
        .order('key');
      
      setTranslations(data || []);
      setEditingTranslation(null);
    } catch (error) {
      console.error('Error saving translation:', error);
    }
  };
  
  // Add new translation
  const addNewTranslation = () => {
    setEditingTranslation({
      id: null,
      namespace: selectedNamespace,
      key: '',
      language_code: selectedLanguage,
      value: '',
    });
  };
  
  if (isLoading && (!languages.length || !namespaces.length)) {
    return <div>Loading translation manager...</div>;
  }
  
  return (
    <div className="translation-manager">
      <h1>Translation Manager</h1>
      
      <div className="filters">
        <div className="filter-group">
          <label>Language:</label>
          <select
            value={selectedLanguage}
            onChange={(e) => setSelectedLanguage(e.target.value)}
          >
            {languages.map(lang => (
              <option key={lang.code} value={lang.code}>
                {lang.name} ({lang.native_name})
              </option>
            ))}
          </select>
        </div>
        
        <div className="filter-group">
          <label>Namespace:</label>
          <select
            value={selectedNamespace}
            onChange={(e) => setSelectedNamespace(e.target.value)}
          >
            {namespaces.map(ns => (
              <option key={ns} value={ns}>{ns}</option>
            ))}
          </select>
        </div>
        
        <div className="filter-group">
          <label>Search:</label>
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search keys or values..."
          />
        </div>
        
        <button
          className="add-translation-button"
          onClick={addNewTranslation}
        >
          Add New Translation
        </button>
      </div>
      
      {isLoading ? (
        <div>Loading translations...</div>
      ) : (
        <div className="translations-table">
          <table>
            <thead>
              <tr>
                <th>Key</th>
                <th>Value</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTranslations.map(translation => (
                <tr key={translation.id}>
                  <td>{translation.key}</td>
                  <td>{translation.value}</td>
                  <td>
                    <button
                      className="edit-button"
                      onClick={() => setEditingTranslation(translation)}
                    >
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
              {filteredTranslations.length === 0 && (
                <tr>
                  <td colSpan={3}>No translations found</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
      
      {editingTranslation && (
        <div className="translation-editor-modal">
          <div className="translation-editor">
            <h2>{editingTranslation.id ? 'Edit Translation' : 'Add Translation'}</h2>
            
            <div className="form-group">
              <label>Key:</label>
              <input
                type="text"
                value={editingTranslation.key}
                onChange={(e) => setEditingTranslation({
                  ...editingTranslation,
                  key: e.target.value,
                })}
              />
            </div>
            
            <div className="form-group">
              <label>Value:</label>
              <textarea
                value={editingTranslation.value}
                onChange={(e) => setEditingTranslation({
                  ...editingTranslation,
                  value: e.target.value,
                })}
                rows={5}
              />
            </div>
            
            <div className="button-group">
              <button
                className="cancel-button"
                onClick={() => setEditingTranslation(null)}
              >
                Cancel
              </button>
              <button
                className="save-button"
                onClick={() => saveTranslation(editingTranslation)}
                disabled={!editingTranslation.key || !editingTranslation.value}
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

7. **Create Date and Number Formatting Utilities**
```typescript
// packages/shared/src/i18n/formatting.ts
import { format, formatDistance, formatRelative } from 'date-fns';
import { formatInTimeZone } from 'date-fns-tz';
import enUS from 'date-fns/locale/en-US';
import es from 'date-fns/locale/es';
import fr from 'date-fns/locale/fr';
import de from 'date-fns/locale/de';
import ar from 'date-fns/locale/ar-SA';
import zhCN from 'date-fns/locale/zh-CN';
import ja from 'date-fns/locale/ja';

// Map language codes to date-fns locales
const locales = {
  en: enUS,
  es,
  fr,
  de,
  ar,
  zh: zhCN,
  ja,
};

// Format date
export const formatDate = (
  date: Date | number,
  formatStr: string = 'PPP',
  languageCode: string = 'en',
  timeZone: string = 'UTC'
) => {
  const locale = locales[languageCode] || enUS;
  
  return formatInTimeZone(date, timeZone, formatStr, {
    locale,
  });
};

// Format relative time
export const formatRelativeTime = (
  date: Date | number,
  baseDate: Date | number = new Date(),
  languageCode: string = 'en'
) => {
  const locale = locales[languageCode] || enUS;
  
  return formatRelative(date, baseDate, {
    locale,
  });
};

// Format distance between dates
export const formatTimeDistance = (
  date: Date | number,
  baseDate: Date | number = new Date(),
  languageCode: string = 'en'
) => {
  const locale = locales[languageCode] || enUS;
  
  return formatDistance(date, baseDate, {
    addSuffix: true,
    locale,
  });
};

// Format number
export const formatNumber = (
  number: number,
  languageCode: string = 'en',
  options: Intl.NumberFormatOptions = {}
) => {
  return new Intl.NumberFormat(languageCode, options).format(number);
};

// Format currency
export const formatCurrency = (
  amount: number,
  currencyCode: string = 'USD',
  languageCode: string = 'en'
) => {
  return new Intl.NumberFormat(languageCode, {
    style: 'currency',
    currency: currencyCode,
  }).format(amount);
};
```

8. **Add Language Support to App Layout**
```typescript
// apps/web/app/[locale]/layout.tsx
import { NextIntlClientProvider } from 'next-intl';
import { notFound } from 'next/navigation';
import { LanguageProvider } from '@supa/shared';

// Define locales
const locales = ['en', 'es', 'fr', 'de', 'ar', 'zh', 'ja'];

export default async function LocaleLayout({ children, params: { locale } }) {
  // Validate that the locale is configured
  if (!locales.includes(locale)) {
    notFound();
  }
  
  let messages;
  try {
    messages = (await import(`../../messages/${locale}.json`)).default;
  } catch (error) {
    // Fallback to empty messages
    messages = {};
  }
  
  return (
    <html lang={locale} dir={locale === 'ar' ? 'rtl' : 'ltr'}>
      <body>
        <NextIntlClientProvider locale={locale} messages={messages}>
          <LanguageProvider>
            {children}
          </LanguageProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

## Localization Workflow

1. **Extract Translatable Strings**
   - Use a consistent pattern for marking translatable strings
   - Extract strings to translation files or database

2. **Translate Content**
   - Use the Translation Manager for content editors
   - Support for importing/exporting translations in standard formats

3. **Apply Translations**
   - Use the i18n provider to apply translations throughout the app
   - Format dates, numbers, and currencies according to locale

## User Experience Considerations
- Allow users to easily switch between languages
- Persist language preferences
- Support right-to-left (RTL) languages
- Format dates, times, numbers, and currencies according to locale
- Adapt layouts for different language text lengths
- Provide fallbacks for missing translations

## Security Considerations
- Sanitize user-provided translations to prevent XSS attacks
- Implement proper RLS policies for translation management
- Validate language codes to prevent injection attacks

## Testing
- Test RTL layout support
- Test with various language content lengths
- Test date and number formatting across locales
- Test language switching functionality
- Test fallback behavior for missing translations

## Deployment Checklist
- Ensure database migrations are applied
- Verify RLS policies are working correctly
- Import initial translations for supported languages
- Test language switching in production
- Verify RTL support in production
