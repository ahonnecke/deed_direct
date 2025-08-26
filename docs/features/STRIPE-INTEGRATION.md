# Stripe Integration

## Overview
This feature integrates Stripe payment processing into the application, enabling subscription management, one-time payments, and marketplace transactions.

## Purpose
To provide a complete payment infrastructure for monetizing the application through subscriptions, transaction fees, or one-time payments.

## Technical Implementation

### Database Schema
```sql
-- Add to migrations
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('active','canceled','past_due','trialing')),
  plan_id text not null,
  stripe_customer_id text not null,
  stripe_subscription_id text not null,
  current_period_end timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  stripe_payment_method_id text not null,
  card_brand text,
  card_last4 text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  stripe_invoice_id text not null,
  amount_due integer not null,
  amount_paid integer not null,
  status text not null,
  invoice_pdf text,
  created_at timestamptz not null default now()
);
```

### Required Packages
```bash
pnpm add stripe @stripe/stripe-js @stripe/react-stripe-js
```

### Environment Variables
```
STRIPE_SECRET_KEY=sk_test_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### Implementation Steps

1. **Initialize Stripe Client**
   ```typescript
   // packages/shared/src/stripe/client.ts
   import Stripe from 'stripe';

   export const getStripeClient = () => {
     const secretKey = process.env.STRIPE_SECRET_KEY;
     if (!secretKey) {
       throw new Error('Missing STRIPE_SECRET_KEY');
     }
     return new Stripe(secretKey, {
       apiVersion: '2023-10-16', // Use latest API version
     });
   };
   ```

2. **Create Stripe Customer on User Registration**
   ```typescript
   // supabase/functions/create-stripe-customer/index.ts
   import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
   import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

   const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
     httpClient: Stripe.createFetchHttpClient(),
   });

   serve(async (req) => {
     const { record } = await req.json();
     
     try {
       const customer = await stripe.customers.create({
         email: record.email,
         metadata: {
           supabaseUUID: record.id,
         },
       });
       
       // Store Stripe customer ID in your database
       const { error } = await supabaseAdmin
         .from('user_profiles')
         .update({ stripe_customer_id: customer.id })
         .eq('id', record.id);
         
       if (error) throw error;
       
       return new Response(JSON.stringify({ success: true }), {
         headers: { 'Content-Type': 'application/json' },
         status: 200,
       });
     } catch (error) {
       return new Response(JSON.stringify({ error: error.message }), {
         headers: { 'Content-Type': 'application/json' },
         status: 400,
       });
     }
   });
   ```

3. **Frontend Components**
   ```typescript
   // packages/ui/src/stripe/PaymentForm.tsx
   import { CardElement, useStripe, useElements } from '@stripe/react-stripe-js';
   
   export const PaymentForm = ({ onSuccess }) => {
     const stripe = useStripe();
     const elements = useElements();
     
     const handleSubmit = async (event) => {
       event.preventDefault();
       
       if (!stripe || !elements) {
         return;
       }
       
       const cardElement = elements.getElement(CardElement);
       
       const { error, paymentMethod } = await stripe.createPaymentMethod({
         type: 'card',
         card: cardElement,
       });
       
       if (error) {
         console.log('[error]', error);
       } else {
         onSuccess(paymentMethod);
       }
     };
     
     return (
       <form onSubmit={handleSubmit}>
         <CardElement />
         <button type="submit" disabled={!stripe}>
           Add Payment Method
         </button>
       </form>
     );
   };
   ```

4. **Webhook Handler**
   ```typescript
   // supabase/functions/stripe-webhook/index.ts
   import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
   import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

   const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
     httpClient: Stripe.createFetchHttpClient(),
   });
   const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') || '';

   serve(async (req) => {
     const signature = req.headers.get('stripe-signature');
     const body = await req.text();
     
     try {
       const event = stripe.webhooks.constructEvent(
         body,
         signature,
         webhookSecret
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
         // Add more event handlers as needed
       }
       
       return new Response(JSON.stringify({ received: true }), {
         headers: { 'Content-Type': 'application/json' },
         status: 200,
       });
     } catch (error) {
       return new Response(JSON.stringify({ error: error.message }), {
         headers: { 'Content-Type': 'application/json' },
         status: 400,
       });
     }
   });
   
   async function handleSubscriptionChange(subscription) {
     // Update subscription status in database
   }
   
   async function handleInvoicePaid(invoice) {
     // Record invoice in database
   }
   ```

5. **Subscription Management UI**
   ```typescript
   // apps/web/app/app/billing/page.tsx
   // Implement subscription management UI
   ```

## Security Considerations
- Never log full card details
- Use Stripe Elements to avoid handling sensitive payment information
- Validate webhook signatures
- Implement proper error handling for payment failures
- Use RLS policies to restrict access to payment data

## Testing
- Use Stripe test mode and test cards
- Test webhook handling with Stripe CLI
- Test subscription lifecycle (create, update, cancel)
- Test payment failures and recovery

## Deployment Checklist
- Set up Stripe webhook endpoints
- Configure environment variables in production
- Ensure database migrations are applied
- Test end-to-end payment flow in production environment
