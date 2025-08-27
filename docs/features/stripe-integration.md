# Stripe Integration

## Overview
Integration with Stripe for handling payments, subscriptions, and billing in the application.

## Purpose
To provide secure payment processing, subscription management, and billing capabilities.

## Technical Implementation

### Database Schema
```sql
-- Create subscriptions table
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  stripe_customer_id text,
  stripe_subscription_id text,
  status text not null,
  plan_id text not null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create payment_methods table
create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  stripe_payment_method_id text not null,
  card_brand text,
  card_last4 text,
  card_exp_month integer,
  card_exp_year integer,
  is_default boolean default false,
  created_at timestamptz not null default now()
);

-- Create invoices table
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  stripe_invoice_id text not null,
  amount_due integer not null,
  amount_paid integer not null,
  currency text not null,
  invoice_pdf text,
  status text not null,
  created_at timestamptz not null default now()
);

-- Add RLS policies
alter table public.subscriptions enable row level security;
alter table public.payment_methods enable row level security;
alter table public.invoices enable row level security;

-- Users can view their own subscriptions
create policy "Users can view their own subscriptions"
  on public.subscriptions for select
  using (auth.uid() = user_id);

-- Users can view their own payment methods
create policy "Users can view their own payment methods"
  on public.payment_methods for select
  using (auth.uid() = user_id);

-- Users can view their own invoices
create policy "Users can view their own invoices"
  on public.invoices for select
  using (auth.uid() = user_id);
```

### Required Packages
```bash
pnpm add stripe @stripe/stripe-js @stripe/react-stripe-js
```

### Implementation Steps

1. **Set up Stripe Edge Function**
```typescript
// supabase/functions/payments/index.ts
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { stripe } from './stripe.ts';

serve(async (req) => {
  const { method, url } = req;
  const path = new URL(url).pathname.split('/').pop();

  try {
    // Handle webhook events from Stripe
    if (method === 'POST' && path === 'webhook') {
      const signature = req.headers.get('stripe-signature');
      const body = await req.text();
      
      const event = stripe.webhooks.constructEvent(
        body,
        signature,
        Deno.env.get('STRIPE_WEBHOOK_SECRET')
      );
      
      // Handle different event types
      switch (event.type) {
        case 'customer.subscription.created':
        case 'customer.subscription.updated':
          await handleSubscriptionChange(event.data.object);
          break;
        case 'invoice.paid':
          await handleInvoicePaid(event.data.object);
          break;
        case 'payment_method.attached':
          await handlePaymentMethodAttached(event.data.object);
          break;
      }
      
      return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }
    
    // Handle client-side requests
    if (method === 'POST') {
      const { action, data } = await req.json();
      
      switch (action) {
        case 'create-checkout-session':
          return await createCheckoutSession(data);
        case 'create-billing-portal-session':
          return await createBillingPortalSession(data);
        case 'get-subscription':
          return await getSubscription(data);
      }
    }
    
    return new Response(JSON.stringify({ error: 'Not Found' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 404,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
```

2. **Create Stripe Client**
```typescript
// packages/shared/src/stripe/client.ts
import { loadStripe } from '@stripe/stripe-js';
import { createBrowserClient } from '@supabase/ssr';

// Initialize Stripe
let stripePromise;
export const getStripe = () => {
  if (!stripePromise) {
    stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY);
  }
  return stripePromise;
};

// Create checkout session
export const createCheckoutSession = async (priceId) => {
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
  
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session) {
    throw new Error('You must be logged in to checkout');
  }
  
  const { data, error } = await supabase.functions.invoke('payments', {
    body: {
      action: 'create-checkout-session',
      data: {
        priceId,
        userId: session.user.id,
        returnUrl: `${window.location.origin}/app/billing/success`,
      },
    },
  });
  
  if (error) throw error;
  return data;
};

// Get user subscription
export const getUserSubscription = async () => {
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
  
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session) {
    return null;
  }
  
  const { data, error } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', session.user.id)
    .single();
  
  if (error && error.code !== 'PGRST116') {
    console.error('Error fetching subscription:', error);
  }
  
  return data;
};
```

3. **Create Subscription Components**
```typescript
// packages/ui/src/stripe/PricingTable.tsx
'use client';

import { useState } from 'react';
import { createCheckoutSession, getUserSubscription } from '@supa/shared';

export function PricingTable({ prices }) {
  const [isLoading, setIsLoading] = useState(false);
  
  const handleCheckout = async (priceId) => {
    setIsLoading(true);
    
    try {
      const { sessionId } = await createCheckoutSession(priceId);
      const stripe = await getStripe();
      await stripe.redirectToCheckout({ sessionId });
    } catch (error) {
      console.error('Error during checkout:', error);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <div className="pricing-table">
      {prices.map((price) => (
        <div key={price.id} className="pricing-card">
          <h3>{price.name}</h3>
          <p className="price">${price.amount / 100} / {price.interval}</p>
          <ul className="features">
            {price.features.map((feature, i) => (
              <li key={i}>{feature}</li>
            ))}
          </ul>
          <button 
            onClick={() => handleCheckout(price.id)}
            disabled={isLoading}
          >
            {isLoading ? 'Processing...' : 'Subscribe'}
          </button>
        </div>
      ))}
    </div>
  );
}
```

4. **Create Billing Management Page**
```typescript
// apps/web/app/app/billing/page.tsx
'use client';

import { useEffect, useState } from 'react';
import { getUserSubscription } from '@supa/shared';
import { PricingTable } from '@supa/ui';

export default function BillingPage() {
  const [subscription, setSubscription] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    async function loadSubscription() {
      try {
        const sub = await getUserSubscription();
        setSubscription(sub);
      } catch (error) {
        console.error('Error loading subscription:', error);
      } finally {
        setIsLoading(false);
      }
    }
    
    loadSubscription();
  }, []);
  
  const prices = [
    {
      id: 'price_basic',
      name: 'Basic',
      amount: 999,
      interval: 'month',
      features: ['Feature 1', 'Feature 2'],
    },
    {
      id: 'price_pro',
      name: 'Pro',
      amount: 1999,
      interval: 'month',
      features: ['Feature 1', 'Feature 2', 'Feature 3', 'Feature 4'],
    },
  ];
  
  if (isLoading) {
    return <div>Loading subscription details...</div>;
  }
  
  return (
    <div className="billing-page">
      <h1>Billing</h1>
      
      {subscription ? (
        <div className="subscription-details">
          <h2>Current Subscription</h2>
          <p>Plan: {subscription.plan_id}</p>
          <p>Status: {subscription.status}</p>
          <p>
            Current period: {new Date(subscription.current_period_start).toLocaleDateString()} 
            to {new Date(subscription.current_period_end).toLocaleDateString()}
          </p>
          <button onClick={handleManageBilling}>Manage Billing</button>
        </div>
      ) : (
        <>
          <p>You don't have an active subscription.</p>
          <PricingTable prices={prices} />
        </>
      )}
    </div>
  );
}
```

## Security Considerations
- Store Stripe API keys securely in environment variables
- Use Supabase Edge Functions for sensitive payment operations
- Implement proper webhook signature verification
- Use RLS policies to protect payment data
- Never log full payment details

## Testing
- Test subscription creation and management
- Test webhook handling for various Stripe events
- Test error handling for failed payments
- Test subscription cancellation flow

## Deployment Checklist
- Set up Stripe account and API keys
- Configure webhook endpoints
- Deploy Supabase Edge Functions
- Test end-to-end payment flow in production
- Set up monitoring for payment failures
