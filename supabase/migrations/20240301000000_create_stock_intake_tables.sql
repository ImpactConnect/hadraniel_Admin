-- Create stock_intake table for cloud sync
create table if not exists public.stock_intake (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  quantity_received real not null,
  unit text not null,
  cost_per_unit real not null,
  total_cost real not null,
  description text,
  date_received timestamp with time zone not null,
  created_at timestamp with time zone not null default now()
);

-- Create intake_balances table for cloud sync
create table if not exists public.intake_balances (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  total_received real not null,
  total_assigned real default 0,
  balance_quantity real not null,
  last_updated timestamp with time zone not null default now()
);

-- Add RLS policies for stock_intake
alter table public.stock_intake enable row level security;

-- Create policy for admins to view all stock intakes
create policy "Admins can view all stock intakes"
  on public.stock_intake
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert stock intakes
create policy "Admins can insert stock intakes"
  on public.stock_intake
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update stock intakes
create policy "Admins can update stock intakes"
  on public.stock_intake
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Add RLS policies for intake_balances
alter table public.intake_balances enable row level security;

-- Create policy for admins to view all intake balances
create policy "Admins can view all intake balances"
  on public.intake_balances
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert intake balances
create policy "Admins can insert intake balances"
  on public.intake_balances
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update intake balances
create policy "Admins can update intake balances"
  on public.intake_balances
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create indexes for better query performance
create index if not exists idx_stock_intake_product_name on public.stock_intake(product_name);
create index if not exists idx_stock_intake_date_received on public.stock_intake(date_received);
create index if not exists idx_stock_intake_created_at on public.stock_intake(created_at);
create index if not exists idx_intake_balances_product_name on public.intake_balances(product_name);
create index if not exists idx_intake_balances_last_updated on public.intake_balances(last_updated);