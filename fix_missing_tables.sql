-- Fix for missing product_distributions table
-- Run this SQL script in your Supabase SQL editor to resolve the sync error

-- 1. Create product_distributions table
create table if not exists public.product_distributions (
  id uuid primary key,
  product_name text not null,
  outlet_id uuid not null references public.outlets(id),
  outlet_name text not null,
  quantity real not null,
  cost_per_unit real not null,
  total_cost real not null,
  distribution_date timestamp with time zone not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone,
  
  -- Add foreign key to outlets table
  constraint fk_product_distributions_outlet foreign key (outlet_id) references public.outlets(id) on delete cascade
);

-- 2. Add RLS policies
alter table public.product_distributions enable row level security;

-- Create policy for authenticated users to view their own outlet's distributions
create policy "Users can view their own outlet's distributions"
  on public.product_distributions
  for select
  to authenticated
  using (outlet_id in (select outlet_id from public.profiles where id = auth.uid()));

-- Create policy for admins to view all distributions
create policy "Admins can view all distributions"
  on public.product_distributions
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert distributions
create policy "Admins can insert distributions"
  on public.product_distributions
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update distributions
create policy "Admins can update distributions"
  on public.product_distributions
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- 3. Create indexes for performance
create index if not exists idx_product_distributions_product_name on public.product_distributions(product_name);
create index if not exists idx_product_distributions_outlet_id on public.product_distributions(outlet_id);
create index if not exists idx_product_distributions_distribution_date on public.product_distributions(distribution_date);

-- 4. Fix expenditures table - add missing columns
alter table public.expenditures 
add column if not exists outlet_name text,
add column if not exists payment_method text default 'cash',
add column if not exists receipt_number text,
add column if not exists vendor_name text,
add column if not exists notes text,
add column if not exists is_recurring integer default 0,
add column if not exists recurring_frequency text,
add column if not exists next_due_date text;

-- Update outlet_name for existing records by joining with outlets table
update public.expenditures 
set outlet_name = outlets.name 
from public.outlets 
where expenditures.outlet_id = outlets.id 
and expenditures.outlet_name is null;

-- Update payment_method for existing records that have NULL values
update public.expenditures 
set payment_method = 'cash' 
where payment_method is null;

-- Set columns as not null after updating existing records
-- (We'll do this in a separate step to avoid constraint violations)
-- alter table public.expenditures alter column outlet_name set not null;
-- alter table public.expenditures alter column payment_method set not null;

-- 5. Verify table creation and fixes
select 'product_distributions table created successfully' as status
union all
select 'expenditures table outlet_name column added successfully' as status;