-- Add approval workflow columns back to expenditures table
-- This migration adds status, approved_by, rejected_by, and rejection_reason columns
-- to match the local app database structure

-- Add approval workflow columns
alter table public.expenditures 
add column if not exists status text default 'pending',
add column if not exists approved_by uuid references auth.users(id),
add column if not exists rejected_by uuid references auth.users(id),
add column if not exists rejection_reason text;

-- Create index for status column for better performance
create index if not exists idx_expenditures_status on public.expenditures(status);

-- Update existing records to have 'approved' status by default
update public.expenditures 
set status = 'approved' 
where status is null or status = '';

-- Add constraint to ensure status has valid values
alter table public.expenditures 
add constraint check_expenditure_status 
check (status in ('pending', 'approved', 'rejected'));

-- Update RLS policies to handle approval workflow

-- Drop existing policies
drop policy if exists "Users can view expenditures" on public.expenditures;
drop policy if exists "Users can insert expenditures" on public.expenditures;
drop policy if exists "Users can update expenditures" on public.expenditures;
drop policy if exists "Users can delete expenditures" on public.expenditures;

-- Create new policies that consider approval status

-- Policy for viewing expenditures (all authenticated users can view)
create policy "Users can view expenditures" on public.expenditures
  for select using (auth.role() = 'authenticated');

-- Policy for inserting expenditures (authenticated users can insert with pending status)
create policy "Users can insert expenditures" on public.expenditures
  for insert with check (
    auth.role() = 'authenticated' and 
    (status = 'pending' or status is null)
  );

-- Policy for updating expenditures
-- Users can update their own pending expenditures
-- Admins can approve/reject expenditures
create policy "Users can update expenditures" on public.expenditures
  for update using (
    auth.role() = 'authenticated' and (
      -- Users can update pending expenditures
      status = 'pending' or
      -- Or if updating approval status (for admins)
      (status in ('approved', 'rejected'))
    )
  );

-- Policy for deleting expenditures (only pending expenditures can be deleted)
create policy "Users can delete expenditures" on public.expenditures
  for delete using (
    auth.role() = 'authenticated' and 
    status = 'pending'
  );

-- Add trigger to automatically update the updated_at timestamp
create or replace function update_expenditures_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger expenditures_updated_at_trigger
  before update on public.expenditures
  for each row
  execute function update_expenditures_updated_at();

-- Add function to handle expenditure approval
create or replace function approve_expenditure(expenditure_id uuid)
returns void as $$
begin
  update public.expenditures
  set 
    status = 'approved',
    approved_by = auth.uid(),
    rejected_by = null,
    rejection_reason = null,
    updated_at = now()
  where id = expenditure_id;
end;
$$ language plpgsql security definer;

-- Add function to handle expenditure rejection
create or replace function reject_expenditure(expenditure_id uuid, reason text)
returns void as $$
begin
  update public.expenditures
  set 
    status = 'rejected',
    rejected_by = auth.uid(),
    approved_by = null,
    rejection_reason = reason,
    updated_at = now()
  where id = expenditure_id;
end;
$$ language plpgsql security definer;