-- Create expenditures table for cloud sync
create table if not exists public.expenditures (
  id uuid primary key,
  description text not null,
  amount real not null,
  category text not null,
  outlet_id uuid not null references public.outlets(id),
  date_incurred timestamp with time zone not null,
  status text not null default 'pending',
  approved_by uuid references public.profiles(id),
  rejected_by uuid references public.profiles(id),
  rejection_reason text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone default now()
);

-- Create expenditure_categories table for cloud sync
create table if not exists public.expenditure_categories (
  id uuid primary key,
  name text not null unique,
  icon text not null,
  created_at timestamp with time zone not null default now()
);

-- Add RLS policies
alter table public.expenditures enable row level security;
alter table public.expenditure_categories enable row level security;

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

-- Create policy for authenticated users to view expenditure categories
create policy "Users can view expenditure categories" on public.expenditure_categories
  for select using (auth.role() = 'authenticated');

-- Create policy for authenticated users to insert expenditure categories
create policy "Users can insert expenditure categories" on public.expenditure_categories
  for insert with check (auth.role() = 'authenticated');

-- Create policy for authenticated users to update expenditure categories
create policy "Users can update expenditure categories" on public.expenditure_categories
  for update using (auth.role() = 'authenticated');

-- Create policy for authenticated users to delete expenditure categories
create policy "Users can delete expenditure categories" on public.expenditure_categories
  for delete using (auth.role() = 'authenticated');

-- Create indexes for better performance
create index if not exists idx_expenditures_outlet_id on public.expenditures(outlet_id);
create index if not exists idx_expenditures_date_incurred on public.expenditures(date_incurred);
create index if not exists idx_expenditures_status on public.expenditures(status);
create index if not exists idx_expenditures_category on public.expenditures(category);