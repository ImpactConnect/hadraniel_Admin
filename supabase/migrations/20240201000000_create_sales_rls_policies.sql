-- Enable RLS for sales and sale_items tables
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;

-- Create policy for admins to view all sales
create policy "Admins can view all sales"
  on public.sales
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert sales
create policy "Admins can insert sales"
  on public.sales
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update sales
create policy "Admins can update sales"
  on public.sales
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to view all sale items
create policy "Admins can view all sale items"
  on public.sale_items
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert sale items
create policy "Admins can insert sale items"
  on public.sale_items
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update sale items
create policy "Admins can update sale items"
  on public.sale_items
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));