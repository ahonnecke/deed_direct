# User Feedback System

## Overview
The User Feedback System enables users to submit feedback, bug reports, feature requests, and general comments directly within the application. This system helps collect valuable user insights during the MVP phase and beyond.

## Purpose
To create a structured way to gather, track, and respond to user feedback, helping prioritize development efforts and improve the product based on actual user needs.

## Technical Implementation

### Database Schema
```sql
-- Add to migrations
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  type text not null check (type in ('bug','feature','general','support')),
  title text not null,
  message text not null,
  status text not null default 'new' check (status in ('new','in_progress','resolved','closed')),
  priority text not null default 'medium' check (priority in ('low','medium','high','critical')),
  metadata jsonb default '{}'::jsonb,
  admin_notes text,
  resolved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add index for faster queries
create index if not exists idx_feedback_user_id on public.feedback (user_id);
create index if not exists idx_feedback_status on public.feedback (status);
create index if not exists idx_feedback_type on public.feedback (type);

-- Add RLS policies
alter table public.feedback enable row level security;

-- Users can view their own feedback
create policy "Users can view their own feedback"
  on public.feedback for select
  using (auth.uid() = user_id);

-- Users can insert their own feedback
create policy "Users can insert their own feedback"
  on public.feedback for insert
  with check (auth.uid() = user_id);

-- Only admins can update feedback
create policy "Admins can update any feedback"
  on public.feedback for update
  using (auth.uid() in (select id from public.user_profiles where is_admin = true));
```

### Required Packages
```bash
pnpm add react-hook-form zod @hookform/resolvers
```

### Implementation Steps

1. **Create Feedback Form Component**
   ```typescript
   // packages/ui/src/feedback/FeedbackForm.tsx
   import { useState } from 'react';
   import { useForm } from 'react-hook-form';
   import { zodResolver } from '@hookform/resolvers/zod';
   import { z } from 'zod';
   
   const feedbackSchema = z.object({
     type: z.enum(['bug', 'feature', 'general', 'support']),
     title: z.string().min(5, 'Title must be at least 5 characters'),
     message: z.string().min(10, 'Message must be at least 10 characters'),
   });
   
   type FeedbackFormData = z.infer<typeof feedbackSchema>;
   
   interface FeedbackFormProps {
     onSubmit: (data: FeedbackFormData) => Promise<void>;
     isSubmitting: boolean;
   }
   
   export function FeedbackForm({ onSubmit, isSubmitting }: FeedbackFormProps) {
     const { register, handleSubmit, formState: { errors }, reset } = useForm<FeedbackFormData>({
       resolver: zodResolver(feedbackSchema),
       defaultValues: {
         type: 'general',
       },
     });
     
     const [submitSuccess, setSubmitSuccess] = useState(false);
     
     const handleFormSubmit = async (data: FeedbackFormData) => {
       try {
         await onSubmit(data);
         reset();
         setSubmitSuccess(true);
         setTimeout(() => setSubmitSuccess(false), 3000);
       } catch (error) {
         console.error('Error submitting feedback:', error);
       }
     };
     
     return (
       <div className="feedback-form-container">
         <h2>Share Your Feedback</h2>
         {submitSuccess && (
           <div className="success-message">
             Thank you for your feedback!
           </div>
         )}
         <form onSubmit={handleSubmit(handleFormSubmit)}>
           <div className="form-group">
             <label htmlFor="type">Feedback Type</label>
             <select id="type" {...register('type')}>
               <option value="general">General Feedback</option>
               <option value="bug">Report a Bug</option>
               <option value="feature">Feature Request</option>
               <option value="support">Support Request</option>
             </select>
             {errors.type && <p className="error">{errors.type.message}</p>}
           </div>
           
           <div className="form-group">
             <label htmlFor="title">Title</label>
             <input
               id="title"
               type="text"
               placeholder="Brief summary of your feedback"
               {...register('title')}
             />
             {errors.title && <p className="error">{errors.title.message}</p>}
           </div>
           
           <div className="form-group">
             <label htmlFor="message">Message</label>
             <textarea
               id="message"
               placeholder="Please provide details..."
               rows={5}
               {...register('message')}
             />
             {errors.message && <p className="error">{errors.message.message}</p>}
           </div>
           
           <button type="submit" disabled={isSubmitting}>
             {isSubmitting ? 'Submitting...' : 'Submit Feedback'}
           </button>
         </form>
       </div>
     );
   }
   ```

2. **Create Feedback Service**
   ```typescript
   // packages/shared/src/services/feedback.ts
   import { createPublicClient } from '@supa/supabase';
   
   export interface FeedbackData {
     type: 'bug' | 'feature' | 'general' | 'support';
     title: string;
     message: string;
     metadata?: Record<string, any>;
   }
   
   export async function submitFeedback(data: FeedbackData) {
     const supabase = createPublicClient();
     const user = await supabase.auth.getUser();
     
     if (!user.data.user) {
       throw new Error('User must be authenticated to submit feedback');
     }
     
     const { error } = await supabase
       .from('feedback')
       .insert({
         user_id: user.data.user.id,
         type: data.type,
         title: data.title,
         message: data.message,
         metadata: data.metadata || {},
       });
     
     if (error) {
       throw error;
     }
     
     return { success: true };
   }
   
   export async function getUserFeedback() {
     const supabase = createPublicClient();
     
     const { data, error } = await supabase
       .from('feedback')
       .select('*')
       .order('created_at', { ascending: false });
     
     if (error) {
       throw error;
     }
     
     return data;
   }
   ```

3. **Implement Feedback Modal**
   ```typescript
   // packages/ui/src/feedback/FeedbackModal.tsx
   import { useState } from 'react';
   import { FeedbackForm } from './FeedbackForm';
   import { submitFeedback } from '@supa/shared';
   
   interface FeedbackModalProps {
     isOpen: boolean;
     onClose: () => void;
   }
   
   export function FeedbackModal({ isOpen, onClose }: FeedbackModalProps) {
     const [isSubmitting, setIsSubmitting] = useState(false);
     
     if (!isOpen) return null;
     
     const handleSubmit = async (data) => {
       setIsSubmitting(true);
       try {
         await submitFeedback(data);
         onClose();
       } catch (error) {
         console.error('Error submitting feedback:', error);
       } finally {
         setIsSubmitting(false);
       }
     };
     
     return (
       <div className="modal-overlay">
         <div className="modal-content">
           <button className="close-button" onClick={onClose}>×</button>
           <FeedbackForm onSubmit={handleSubmit} isSubmitting={isSubmitting} />
         </div>
       </div>
     );
   }
   ```

4. **Add Feedback Button Component**
   ```typescript
   // packages/ui/src/feedback/FeedbackButton.tsx
   import { useState } from 'react';
   import { FeedbackModal } from './FeedbackModal';
   
   export function FeedbackButton() {
     const [isModalOpen, setIsModalOpen] = useState(false);
     
     return (
       <>
         <button
           className="feedback-button"
           onClick={() => setIsModalOpen(true)}
         >
           Feedback
         </button>
         <FeedbackModal
           isOpen={isModalOpen}
           onClose={() => setIsModalOpen(false)}
         />
       </>
     );
   }
   ```

5. **Add User Feedback History Page**
   ```typescript
   // apps/web/app/app/feedback/page.tsx
   'use client';
   
   import { useState, useEffect } from 'react';
   import { getUserFeedback } from '@supa/shared';
   
   export default function FeedbackHistoryPage() {
     const [feedback, setFeedback] = useState([]);
     const [isLoading, setIsLoading] = useState(true);
     const [error, setError] = useState(null);
     
     useEffect(() => {
       async function loadFeedback() {
         try {
           const data = await getUserFeedback();
           setFeedback(data);
         } catch (err) {
           setError(err.message);
         } finally {
           setIsLoading(false);
         }
       }
       
       loadFeedback();
     }, []);
     
     if (isLoading) return <div>Loading...</div>;
     if (error) return <div>Error: {error}</div>;
     
     return (
       <div className="feedback-history">
         <h1>Your Feedback History</h1>
         {feedback.length === 0 ? (
           <p>You haven't submitted any feedback yet.</p>
         ) : (
           <ul className="feedback-list">
             {feedback.map((item) => (
               <li key={item.id} className="feedback-item">
                 <div className="feedback-header">
                   <h3>{item.title}</h3>
                   <span className={`badge ${item.type}`}>{item.type}</span>
                   <span className={`badge ${item.status}`}>{item.status}</span>
                 </div>
                 <p>{item.message}</p>
                 <div className="feedback-meta">
                   <span>Submitted: {new Date(item.created_at).toLocaleDateString()}</span>
                 </div>
               </li>
             ))}
           </ul>
         )}
       </div>
     );
   }
   ```

6. **Add Feedback Button to Layout**
   ```typescript
   // apps/web/app/layout.tsx
   import { FeedbackButton } from '@supa/ui';
   
   export default function RootLayout({ children }) {
     return (
       <html lang="en">
         <body>
           {children}
           <FeedbackButton />
         </body>
       </html>
     );
   }
   ```

## User Experience Considerations
- Make the feedback button accessible but not intrusive
- Provide clear categories for different types of feedback
- Allow users to attach screenshots or system information for bug reports
- Show users the status of their previous feedback submissions
- Send notifications when feedback status changes

## Admin Features
- View all feedback in the admin dashboard
- Filter and sort by type, status, and priority
- Assign feedback items to team members
- Update status and add internal notes
- Export feedback data for analysis

## Analytics Integration
- Track feedback submission rates
- Analyze common feedback themes
- Measure resolution times
- Correlate feedback with user segments

## Testing
- Test form validation
- Test submission flow with authenticated and unauthenticated users
- Test feedback history retrieval
- Test admin features and permissions

## Deployment Checklist
- Ensure database migrations are applied
- Verify RLS policies are working correctly
- Test the complete feedback submission flow in production
- Set up notifications for new feedback submissions
