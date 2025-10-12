-- Enable RLS for products table
alter table public.products enable row level security;

-- Create policy for admins to view all products
create policy "Admins can view all products"
  on public.products
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert products
create policy "Admins can insert products"
  on public.products
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update products
create policy "Admins can update products"
  on public.products
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to delete products
create policy "Admins can delete products"
  on public.products
  for delete
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for users to view products for their outlets
create policy "Users can view products for their outlets"
  on public.products
  for select
  to authenticated
  using (
    outlet_id in (
      select outlet_id from public.profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from public.profiles where id = auth.uid() and role = 'admin'
    )
  );