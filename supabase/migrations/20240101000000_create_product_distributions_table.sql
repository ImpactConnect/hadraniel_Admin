-- Create product_distributions table for cloud sync
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

-- Add RLS policies
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

-- Create index for faster queries
create index if not exists idx_product_distributions_product_name on public.product_distributions(product_name);
create index if not exists idx_product_distributions_outlet_id on public.product_distributions(outlet_id);
create index if not exists idx_product_distributions_distribution_date on public.product_distributions(distribution_date);