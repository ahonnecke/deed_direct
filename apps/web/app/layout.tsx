// apps/web/app/layout.tsx
"use client";

import React from 'react';
import { AuthProvider } from '@supa/supabase/src/auth-context';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>
          {children}
        </AuthProvider>
      </body>
    </html>
  )
}
