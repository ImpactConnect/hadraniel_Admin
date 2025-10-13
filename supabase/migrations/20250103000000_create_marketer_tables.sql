-- Create marketers table (UUID schema)
create table if not exists public.marketers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text,
  phone text,
  outlet_id uuid not null references public.outlets(id) on delete cascade,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- Optional sync flag for diagnostics
alter table public.marketers
  add column if not exists is_synced integer not null default 0;

-- Indexes
create index if not exists idx_marketers_outlet_id on public.marketers (outlet_id);
create index if not exists idx_marketers_status on public.marketers (status);

-- Create marketer_targets table (UUID schema)
create table if not exists public.marketer_targets (
  id uuid primary key default gen_random_uuid(),
  marketer_id uuid not null references public.marketers(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  outlet_id uuid not null references public.outlets(id) on delete cascade,
  target_quantity numeric,
  target_revenue numeric,
  target_type text not null default 'quantity' check (target_type in ('quantity','revenue')),
  start_date timestamp with time zone not null,
  end_date timestamp with time zone not null,
  current_quantity numeric default 0,
  current_revenue numeric default 0,
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  is_synced integer not null default 0
);

-- Indexes for targets
create index if not exists idx_targets_marketer_id on public.marketer_targets (marketer_id);
create index if not exists idx_targets_product_id on public.marketer_targets (product_id);
create index if not exists idx_targets_outlet_id on public.marketer_targets (outlet_id);

-- Updated-at trigger function (shared)
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Triggers
drop trigger if exists marketers_set_updated_at on public.marketers;
create trigger marketers_set_updated_at
before update on public.marketers
for each row execute procedure public.set_updated_at();

drop trigger if exists marketer_targets_set_updated_at on public.marketer_targets;
create trigger marketer_targets_set_updated_at
before update on public.marketer_targets
for each row execute procedure public.set_updated_at();

-- Enable RLS
alter table public.marketers enable row level security;
alter table public.marketer_targets enable row level security;

-- Policies: outlet-scoped access; admins can access all
create policy if not exists "Marketers select for outlet or admin"
  on public.marketers
  for select to authenticated
  using (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Marketers insert for outlet or admin"
  on public.marketers
  for insert to authenticated
  with check (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Marketers update for outlet or admin"
  on public.marketers
  for update to authenticated
  using (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  )
  with check (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Marketers delete for outlet or admin"
  on public.marketers
  for delete to authenticated
  using (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Targets select for outlet or admin"
  on public.marketer_targets
  for select to authenticated
  using (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Targets insert for outlet or admin"
  on public.marketer_targets
  for insert to authenticated
  with check (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Targets update for outlet or admin"
  on public.marketer_targets
  for update to authenticated
  using (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  )
  with check (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy if not exists "Targets delete for outlet or admin"
  on public.marketer_targets
  for delete to authenticated
  using (
    outlet_id in (select outlet_id from public.profiles where id = auth.uid())
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );