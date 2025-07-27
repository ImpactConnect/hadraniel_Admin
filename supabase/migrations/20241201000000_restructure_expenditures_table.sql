-- Restructure expenditures table to remove approval workflow
-- This migration removes status, approved_by, rejected_by, and rejection_reason columns

-- Drop existing indexes that reference removed columns
drop index if exists idx_expenditures_status;

-- Create new expenditures table without approval fields
create table if not exists public.expenditures_new (
  id uuid primary key,
  description text not null,
  amount real not null,
  category text not null,
  outlet_id uuid not null references public.outlets(id),
  date_incurred timestamp with time zone not null,
  vendor_name text,
  receipt_number text,
  payment_method text default 'cash',
  notes text,
  is_recurring boolean default false,
  recurring_frequency text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone default now()
);

-- Copy data from old table to new table (excluding approval fields)
insert into public.expenditures_new (
  id, description, amount, category, outlet_id, date_incurred, created_at, updated_at
)
select 
  id, description, amount, category, outlet_id, date_incurred, created_at, updated_at
from public.expenditures;

-- Drop old table
drop table public.expenditures;

-- Rename new table to original name
alter table public.expenditures_new rename to expenditures;

-- Recreate indexes for better performance (excluding status)
create index if not exists idx_expenditures_outlet_id on public.expenditures(outlet_id);
create index if not exists idx_expenditures_date_incurred on public.expenditures(date_incurred);
create index if not exists idx_expenditures_category on public.expenditures(category);
create index if not exists idx_expenditures_payment_method on public.expenditures(payment_method);

-- Add RLS policies for the restructured table
alter table public.expenditures enable row level security;

-- Create policy for authenticated users to view expenditures
create policy "Users can view expenditures" on public.expenditures
  for select using (auth.role() = 'authenticated');

-- Create policy for authenticated users to insert expenditures
create policy "Users can insert expenditures" on public.expenditures
  for insert with check (auth.role() = 'authenticated');

-- Create policy for authenticated users to update expenditures
create policy "Users can update expenditures" on public.expenditures
  for update using (auth.role() = 'authenticated');

-- Create policy for authenticated users to delete expenditures
create policy "Users can delete expenditures" on public.expenditures
  for delete using (auth.role() = 'authenticated');