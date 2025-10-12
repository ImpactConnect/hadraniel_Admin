-- Enable RLS for stock_balances table
alter table public.stock_balances enable row level security;

-- Create policy for admins to view all stock balances
create policy "Admins can view all stock balances"
  on public.stock_balances
  for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to insert stock balances
create policy "Admins can insert stock balances"
  on public.stock_balances
  for insert
  to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to update stock balances
create policy "Admins can update stock balances"
  on public.stock_balances
  for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for admins to delete stock balances
create policy "Admins can delete stock balances"
  on public.stock_balances
  for delete
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- Create policy for users to view stock balances for their outlets
create policy "Users can view stock balances for their outlets"
  on public.stock_balances
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

-- Create policy for users to update stock balances for their outlets
create policy "Users can update stock balances for their outlets"
  on public.stock_balances
  for update
  to authenticated
  using (
    outlet_id in (
      select outlet_id from public.profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from public.profiles where id = auth.uid() and role = 'admin'
    )
  );