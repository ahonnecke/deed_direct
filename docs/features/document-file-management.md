# Document/File Management System

## Overview
A secure file storage and management system leveraging Supabase Storage for uploading, organizing, and sharing documents with appropriate access controls.

## Purpose
To provide users with the ability to upload, organize, share, and collaborate on documents and files within the application.

## Technical Implementation

### Database Schema
```sql
-- Create files table to track metadata
create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  storage_path text not null,
  name text not null,
  size integer not null,
  mime_type text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  parent_folder_id uuid references public.files(id) on delete set null,
  is_folder boolean not null default false,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, parent_folder_id, name, is_folder)
);

-- Create file_permissions table
create table if not exists public.file_permissions (
  id uuid primary key default gen_random_uuid(),
  file_id uuid not null references public.files(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  permission_level text not null check (permission_level in ('view', 'edit', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (file_id, user_id)
);

-- Add RLS policies
alter table public.files enable row level security;
alter table public.file_permissions enable row level security;

-- Files access policies
create policy "Users can view their own files"
  on public.files for select
  using (auth.uid() = owner_id);

create policy "Users can view files shared with them"
  on public.files for select
  using (id in (
    select file_id from public.file_permissions
    where user_id = auth.uid()
  ));

create policy "Users can insert their own files"
  on public.files for insert
  with check (auth.uid() = owner_id);

create policy "Users can update their own files"
  on public.files for update
  using (auth.uid() = owner_id);

create policy "Users can delete their own files"
  on public.files for delete
  using (auth.uid() = owner_id);

-- File permissions access policies
create policy "Users can view permissions for their files"
  on public.file_permissions for select
  using (file_id in (
    select id from public.files where owner_id = auth.uid()
  ));

create policy "Users can manage permissions for their files"
  on public.file_permissions for all
  using (file_id in (
    select id from public.files where owner_id = auth.uid()
  ));
```

### Storage Buckets Setup
```sql
-- Create storage buckets
insert into storage.buckets (id, name, public)
values ('user_files', 'User Files', false)
on conflict do nothing;

-- Set up storage policies
create policy "Users can view their own files"
  on storage.objects for select
  using (auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can upload their own files"
  on storage.objects for insert
  with check (auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can update their own files"
  on storage.objects for update
  using (auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can delete their own files"
  on storage.objects for delete
  using (auth.uid()::text = (storage.foldername(name))[1]);
```

### Core Components

1. **File Upload Service**
```typescript
// packages/shared/src/files/upload.ts
import { createBrowserClient } from '@supabase/ssr';
import { v4 as uuidv4 } from 'uuid';

export const uploadFile = async (file, folderId = null) => {
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
  
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');
  
  // Create storage path
  const storagePath = `${user.id}/${uuidv4()}-${file.name}`;
  
  // Upload file to storage
  const { error: uploadError } = await supabase.storage
    .from('user_files')
    .upload(storagePath, file);
  
  if (uploadError) throw uploadError;
  
  // Create file record in database
  const { data: fileRecord, error: dbError } = await supabase
    .from('files')
    .insert({
      bucket_id: 'user_files',
      storage_path: storagePath,
      name: file.name,
      size: file.size,
      mime_type: file.type,
      owner_id: user.id,
      parent_folder_id: folderId,
      is_folder: false,
    })
    .select()
    .single();
  
  if (dbError) throw dbError;
  
  return fileRecord;
};
```

2. **File Browser Component**
```typescript
// packages/ui/src/files/FileBrowser.tsx
'use client';

import { useState, useEffect } from 'react';
import { createBrowserClient } from '@supabase/ssr';
import { uploadFile } from '@supa/shared';

export function FileBrowser({ folderId = null }) {
  const [files, setFiles] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [currentFolder, setCurrentFolder] = useState(folderId);
  const [breadcrumbs, setBreadcrumbs] = useState([]);
  
  // Load files for current folder
  useEffect(() => {
    const loadFiles = async () => {
      setIsLoading(true);
      
      try {
        const supabase = createBrowserClient(
          process.env.NEXT_PUBLIC_SUPABASE_URL!,
          process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
        );
        
        const { data, error } = await supabase
          .from('files')
          .select('*')
          .eq('parent_folder_id', currentFolder)
          .order('is_folder', { ascending: false })
          .order('name');
        
        if (error) throw error;
        
        setFiles(data || []);
        
        // Load breadcrumbs
        if (currentFolder) {
          await loadBreadcrumbs(currentFolder);
        } else {
          setBreadcrumbs([{ id: null, name: 'Root' }]);
        }
      } catch (error) {
        console.error('Error loading files:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    loadFiles();
  }, [currentFolder]);
  
  // Load breadcrumb path
  const loadBreadcrumbs = async (folderId) => {
    try {
      const path = [];
      let currentId = folderId;
      
      const supabase = createBrowserClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
      );
      
      while (currentId) {
        const { data } = await supabase
          .from('files')
          .select('id, name, parent_folder_id')
          .eq('id', currentId)
          .single();
        
        if (data) {
          path.unshift(data);
          currentId = data.parent_folder_id;
        } else {
          break;
        }
      }
      
      path.unshift({ id: null, name: 'Root' });
      setBreadcrumbs(path);
    } catch (error) {
      console.error('Error loading breadcrumbs:', error);
    }
  };
  
  // Create new folder
  const createFolder = async (folderName) => {
    try {
      const supabase = createBrowserClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
      );
      
      const { data: { user } } = await supabase.auth.getUser();
      
      const { data, error } = await supabase
        .from('files')
        .insert({
          bucket_id: 'user_files',
          storage_path: '',
          name: folderName,
          size: 0,
          mime_type: 'folder',
          owner_id: user.id,
          parent_folder_id: currentFolder,
          is_folder: true,
        })
        .select()
        .single();
      
      if (error) throw error;
      
      // Refresh file list
      setFiles(prev => [...prev, data]);
    } catch (error) {
      console.error('Error creating folder:', error);
    }
  };
  
  // Handle file upload
  const handleFileUpload = async (event) => {
    const file = event.target.files[0];
    if (!file) return;
    
    try {
      const fileRecord = await uploadFile(file, currentFolder);
      
      // Refresh file list
      setFiles(prev => [...prev, fileRecord]);
    } catch (error) {
      console.error('Error uploading file:', error);
    }
  };
  
  // Render component
  return (
    <div className="file-browser">
      <div className="file-browser-header">
        <div className="breadcrumbs">
          {breadcrumbs.map((crumb, index) => (
            <span key={crumb.id || 'root'}>
              {index > 0 && ' / '}
              <button
                className="breadcrumb-link"
                onClick={() => setCurrentFolder(crumb.id)}
              >
                {crumb.name}
              </button>
            </span>
          ))}
        </div>
        
        <div className="file-actions">
          <button
            className="new-folder-button"
            onClick={() => {
              const name = prompt('Enter folder name:');
              if (name) createFolder(name);
            }}
          >
            New Folder
          </button>
          
          <label className="upload-button">
            Upload File
            <input
              type="file"
              onChange={handleFileUpload}
              style={{ display: 'none' }}
            />
          </label>
        </div>
      </div>
      
      {isLoading ? (
        <div className="loading">Loading files...</div>
      ) : (
        <div className="file-list">
          {files.length === 0 ? (
            <div className="empty-state">No files or folders</div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Size</th>
                  <th>Modified</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {files.map(file => (
                  <tr key={file.id}>
                    <td>
                      {file.is_folder ? (
                        <button
                          className="folder-name"
                          onClick={() => setCurrentFolder(file.id)}
                        >
                          📁 {file.name}
                        </button>
                      ) : (
                        <span>📄 {file.name}</span>
                      )}
                    </td>
                    <td>{file.is_folder ? '--' : formatFileSize(file.size)}</td>
                    <td>{new Date(file.updated_at).toLocaleString()}</td>
                    <td>
                      <div className="file-actions">
                        {!file.is_folder && (
                          <button
                            className="download-button"
                            onClick={() => downloadFile(file)}
                          >
                            Download
                          </button>
                        )}
                        <button
                          className="share-button"
                          onClick={() => shareFile(file)}
                        >
                          Share
                        </button>
                        <button
                          className="delete-button"
                          onClick={() => deleteFile(file)}
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}

// Helper functions
function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

async function downloadFile(file) {
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    const { data, error } = await supabase.storage
      .from(file.bucket_id)
      .download(file.storage_path);
    
    if (error) throw error;
    
    // Create download link
    const url = URL.createObjectURL(data);
    const a = document.createElement('a');
    a.href = url;
    a.download = file.name;
    document.body.appendChild(a);
    a.click();
    URL.revokeObjectURL(url);
    document.body.removeChild(a);
  } catch (error) {
    console.error('Error downloading file:', error);
  }
}

async function shareFile(file) {
  // Implementation for sharing file
  alert(`Sharing ${file.name} - Feature to be implemented`);
}

async function deleteFile(file) {
  if (!confirm(`Are you sure you want to delete ${file.name}?`)) {
    return;
  }
  
  try {
    const supabase = createBrowserClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
    
    // Delete from storage if not a folder
    if (!file.is_folder) {
      await supabase.storage
        .from(file.bucket_id)
        .remove([file.storage_path]);
    }
    
    // Delete from database
    await supabase
      .from('files')
      .delete()
      .eq('id', file.id);
    
    // Refresh file list (would be handled by parent component)
    window.location.reload();
  } catch (error) {
    console.error('Error deleting file:', error);
  }
}
```

## Key Features
- Hierarchical folder structure
- File upload with metadata tracking
- File sharing with granular permissions
- Download and preview capabilities
- Version history (optional)
- Search functionality
- Drag-and-drop organization

## Security Considerations
- Implement strict RLS policies for file access
- Validate file types and scan for malware
- Set appropriate file size limits
- Enforce user storage quotas
- Secure sharing links with expiration
- Audit file access and modifications

## User Experience Considerations
- Intuitive file browser interface
- Progress indicators for uploads/downloads
- Preview capabilities for common file types
- Mobile-friendly interface
- Drag-and-drop functionality
- Keyboard shortcuts for power users

## Testing
- Test file uploads of various sizes and types
- Test folder creation and navigation
- Test file sharing and permissions
- Test download functionality
- Test search functionality
- Test on mobile devices

## Deployment Checklist
- Configure storage buckets and policies
- Apply database migrations
- Set appropriate file size limits
- Configure CORS for file uploads
- Test end-to-end file operations
