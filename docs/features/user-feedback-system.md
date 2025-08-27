# User Feedback System

## Overview
A comprehensive system for collecting, managing, and responding to user feedback, including bug reports, feature requests, and general comments.

## Purpose
To establish a direct communication channel with users, gather valuable insights for product improvement, and prioritize development efforts based on user needs.

## Technical Implementation

### Database Schema
```sql
-- Create feedback table
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  type text not null check (type in ('bug', 'feature_request', 'general')),
  title text not null,
  description text not null,
  status text not null default 'new' check (status in ('new', 'in_review', 'planned', 'in_progress', 'completed', 'declined')),
  priority text default 'medium' check (priority in ('low', 'medium', 'high', 'critical')),
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create feedback comments table
create table if not exists public.feedback_comments (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.feedback(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  is_admin boolean not null default false,
  content text not null,
  created_at timestamptz not null default now()
);

-- Create feedback votes table
create table if not exists public.feedback_votes (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.feedback(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (feedback_id, user_id)
);

-- Add RLS policies
alter table public.feedback enable row level security;
alter table public.feedback_comments enable row level security;
alter table public.feedback_votes enable row level security;

-- Everyone can view feedback
create policy "Everyone can view feedback"
  on public.feedback for select
  using (true);

-- Only the author can update their feedback
create policy "Users can update their own feedback"
  on public.feedback for update
  using (auth.uid() = user_id);

-- Anyone can insert feedback
create policy "Anyone can insert feedback"
  on public.feedback for insert
  with check (true);

-- Everyone can view comments
create policy "Everyone can view feedback comments"
  on public.feedback_comments for select
  using (true);

-- Only the author can update their comments
create policy "Users can update their own comments"
  on public.feedback_comments for update
  using (auth.uid() = user_id);

-- Anyone can insert comments
create policy "Anyone can insert feedback comments"
  on public.feedback_comments for insert
  with check (true);

-- Users can vote once per feedback item
create policy "Users can vote on feedback"
  on public.feedback_votes for insert
  with check (auth.uid() = user_id);

-- Users can remove their votes
create policy "Users can remove their votes"
  on public.feedback_votes for delete
  using (auth.uid() = user_id);

-- Users can view votes
create policy "Everyone can view feedback votes"
  on public.feedback_votes for select
  using (true);

-- Add indexes
create index if not exists idx_feedback_user_id on public.feedback (user_id);
create index if not exists idx_feedback_type on public.feedback (type);
create index if not exists idx_feedback_status on public.feedback (status);
create index if not exists idx_feedback_comments_feedback_id on public.feedback_comments (feedback_id);
create index if not exists idx_feedback_votes_feedback_id on public.feedback_votes (feedback_id);
```

### Required Packages
```bash
pnpm add react-hook-form zod @hookform/resolvers react-markdown
```

### Implementation Steps

1. **Create Feedback Form Component**
```typescript
// packages/ui/src/feedback/FeedbackForm.tsx
'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { createPublicClient } from '@supa/supabase';

const feedbackSchema = z.object({
  type: z.enum(['bug', 'feature_request', 'general']),
  title: z.string().min(5, 'Title must be at least 5 characters'),
  description: z.string().min(10, 'Description must be at least 10 characters'),
});

type FeedbackFormData = z.infer<typeof feedbackSchema>;

export function FeedbackForm() {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  
  const { register, handleSubmit, reset, formState: { errors } } = useForm<FeedbackFormData>({
    resolver: zodResolver(feedbackSchema),
    defaultValues: {
      type: 'general',
    },
  });
  
  const onSubmit = async (data: FeedbackFormData) => {
    setIsSubmitting(true);
    
    try {
      const supabase = createPublicClient();
      
      // Get browser and system info
      const metadata = {
        userAgent: navigator.userAgent,
        screenSize: `${window.screen.width}x${window.screen.height}`,
        url: window.location.href,
      };
      
      const { error } = await supabase
        .from('feedback')
        .insert({
          ...data,
          metadata,
        });
      
      if (error) throw error;
      
      setIsSuccess(true);
      reset();
      
      // Reset success message after 5 seconds
      setTimeout(() => setIsSuccess(false), 5000);
    } catch (error) {
      console.error('Error submitting feedback:', error);
    } finally {
      setIsSubmitting(false);
    }
  };
  
  return (
    <div className="feedback-form">
      <h2>Submit Feedback</h2>
      
      {isSuccess && (
        <div className="success-message">
          Thank you for your feedback! We'll review it shortly.
        </div>
      )}
      
      <form onSubmit={handleSubmit(onSubmit)}>
        <div className="form-group">
          <label htmlFor="type">Feedback Type</label>
          <select id="type" {...register('type')}>
            <option value="general">General Feedback</option>
            <option value="bug">Bug Report</option>
            <option value="feature_request">Feature Request</option>
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
          <label htmlFor="description">Description</label>
          <textarea
            id="description"
            placeholder="Please provide details..."
            rows={5}
            {...register('description')}
          />
          {errors.description && <p className="error">{errors.description.message}</p>}
        </div>
        
        <button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Submitting...' : 'Submit Feedback'}
        </button>
      </form>
    </div>
  );
}
```

2. **Create Feedback List Component**
```typescript
// packages/ui/src/feedback/FeedbackList.tsx
'use client';

import { useState, useEffect } from 'react';
import { createPublicClient } from '@supa/supabase';
import { FeedbackItem } from './FeedbackItem';

export function FeedbackList() {
  const [feedback, setFeedback] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [filter, setFilter] = useState({
    type: 'all',
    status: 'all',
    sort: 'newest',
  });
  
  useEffect(() => {
    async function loadFeedback() {
      setIsLoading(true);
      
      try {
        const supabase = createPublicClient();
        
        let query = supabase
          .from('feedback')
          .select(`
            *,
            user:user_id(id, email),
            votes:feedback_votes(count),
            comments:feedback_comments(count)
          `);
        
        // Apply filters
        if (filter.type !== 'all') {
          query = query.eq('type', filter.type);
        }
        
        if (filter.status !== 'all') {
          query = query.eq('status', filter.status);
        }
        
        // Apply sorting
        if (filter.sort === 'newest') {
          query = query.order('created_at', { ascending: false });
        } else if (filter.sort === 'oldest') {
          query = query.order('created_at', { ascending: true });
        } else if (filter.sort === 'most_votes') {
          query = query.order('votes.count', { ascending: false });
        }
        
        const { data, error } = await query;
        
        if (error) throw error;
        
        setFeedback(data || []);
      } catch (error) {
        console.error('Error loading feedback:', error);
      } finally {
        setIsLoading(false);
      }
    }
    
    loadFeedback();
  }, [filter]);
  
  const handleFilterChange = (key, value) => {
    setFilter(prev => ({
      ...prev,
      [key]: value,
    }));
  };
  
  if (isLoading) {
    return <div>Loading feedback...</div>;
  }
  
  return (
    <div className="feedback-list">
      <div className="filters">
        <div className="filter-group">
          <label>Type:</label>
          <select
            value={filter.type}
            onChange={(e) => handleFilterChange('type', e.target.value)}
          >
            <option value="all">All Types</option>
            <option value="bug">Bug Reports</option>
            <option value="feature_request">Feature Requests</option>
            <option value="general">General Feedback</option>
          </select>
        </div>
        
        <div className="filter-group">
          <label>Status:</label>
          <select
            value={filter.status}
            onChange={(e) => handleFilterChange('status', e.target.value)}
          >
            <option value="all">All Statuses</option>
            <option value="new">New</option>
            <option value="in_review">In Review</option>
            <option value="planned">Planned</option>
            <option value="in_progress">In Progress</option>
            <option value="completed">Completed</option>
            <option value="declined">Declined</option>
          </select>
        </div>
        
        <div className="filter-group">
          <label>Sort:</label>
          <select
            value={filter.sort}
            onChange={(e) => handleFilterChange('sort', e.target.value)}
          >
            <option value="newest">Newest First</option>
            <option value="oldest">Oldest First</option>
            <option value="most_votes">Most Votes</option>
          </select>
        </div>
      </div>
      
      {feedback.length === 0 ? (
        <p>No feedback found matching your filters.</p>
      ) : (
        <div className="feedback-items">
          {feedback.map((item) => (
            <FeedbackItem key={item.id} feedback={item} />
          ))}
        </div>
      )}
    </div>
  );
}
```

3. **Create Feedback Detail Page**
```typescript
// apps/web/app/feedback/[id]/page.tsx
import { createSSRClient } from '@supa/supabase';
import { notFound } from 'next/navigation';
import { FeedbackDetail } from './components/FeedbackDetail';
import { CommentSection } from './components/CommentSection';

export default async function FeedbackDetailPage({ params }) {
  const { id } = params;
  const supabase = createSSRClient();
  
  // Get feedback details
  const { data: feedback, error } = await supabase
    .from('feedback')
    .select(`
      *,
      user:user_id(id, email),
      votes:feedback_votes(count),
      comments:feedback_comments(id, user_id, content, created_at, user:user_id(email))
    `)
    .eq('id', id)
    .single();
  
  if (error || !feedback) {
    notFound();
  }
  
  return (
    <div className="feedback-detail-page">
      <FeedbackDetail feedback={feedback} />
      <CommentSection feedbackId={id} comments={feedback.comments} />
    </div>
  );
}
```

4. **Create Admin Feedback Management**
```typescript
// apps/web/app/admin/feedback/page.tsx
import { createSSRClient } from '@supa/supabase';
import { AdminFeedbackList } from './components/AdminFeedbackList';

export default async function AdminFeedbackPage() {
  const supabase = createSSRClient();
  
  // Get feedback with counts
  const { data: feedbackCounts } = await supabase
    .from('feedback')
    .select('status', { count: 'exact', head: true })
    .eq('status', 'new');
  
  const { data: feedback } = await supabase
    .from('feedback')
    .select(`
      *,
      user:user_id(id, email),
      votes:feedback_votes(count),
      comments:feedback_comments(count)
    `)
    .order('created_at', { ascending: false });
  
  return (
    <div className="admin-feedback">
      <h1>Feedback Management</h1>
      
      <div className="stats">
        <div className="stat-card">
          <h3>New Feedback</h3>
          <p className="stat-value">{feedbackCounts || 0}</p>
        </div>
        {/* Add more stat cards as needed */}
      </div>
      
      <AdminFeedbackList feedback={feedback || []} />
    </div>
  );
}
```

5. **Create Feedback Widget**
```typescript
// packages/ui/src/feedback/FeedbackWidget.tsx
'use client';

import { useState } from 'react';
import { FeedbackForm } from './FeedbackForm';

export function FeedbackWidget() {
  const [isOpen, setIsOpen] = useState(false);
  
  return (
    <div className="feedback-widget">
      {isOpen ? (
        <div className="feedback-modal">
          <div className="feedback-modal-header">
            <h2>Share Your Feedback</h2>
            <button 
              className="close-button"
              onClick={() => setIsOpen(false)}
            >
              &times;
            </button>
          </div>
          <div className="feedback-modal-body">
            <FeedbackForm />
          </div>
        </div>
      ) : (
        <button 
          className="feedback-button"
          onClick={() => setIsOpen(true)}
        >
          Feedback
        </button>
      )}
    </div>
  );
}
```

## User Experience Considerations
- Make feedback submission quick and accessible from anywhere in the app
- Provide clear status updates on submitted feedback
- Allow users to track their feedback items
- Enable voting to prioritize popular requests
- Create a transparent roadmap based on feedback

## Security Considerations
- Implement rate limiting to prevent spam
- Sanitize user input to prevent XSS attacks
- Use RLS policies to control access to feedback data
- Moderate comments to prevent abuse

## Testing
- Test feedback submission with various input types
- Test filtering and sorting functionality
- Test voting mechanism
- Test comment system
- Test admin management interface

## Deployment Checklist
- Apply database migrations
- Verify RLS policies
- Set up notifications for new feedback
- Create initial feedback categories
- Train support team on feedback management
