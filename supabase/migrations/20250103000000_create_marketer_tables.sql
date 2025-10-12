-- Create marketers table
create table if not exists public.marketers (
  id text primary key,
  full_name text not null,
  email text not null,
  phone text,
  outlet_id text not null,
  status text default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone,
  is_synced integer default 0,
  constraint fk_marketers_outlet foreign key (outlet_id) references outlets (id)
);

-- Create marketer_targets table
create table if not exists public.marketer_targets (
  id text primary key,
  marketer_id text not null,
  product_id text not null,
  outlet_id text not null,
  target_quantity real,
  target_revenue real,
  target_type text not null default 'quantity',
  start_date timestamp with time zone not null,
  end_date timestamp with time zone not null,
  current_quantity real default 0,
  current_revenue real default 0,
  status text default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone,
  is_synced integer default 0,
  constraint fk_marketer_targets_marketer foreign key (marketer_id) references marketers (id),
  constraint fk_marketer_targets_product foreign key (product_id) references products (id),
  constraint fk_marketer_targets_outlet foreign key (outlet_id) references outlets (id)
);

-- Create indexes for better performance
create index if not exists idx_marketers_outlet_id on public.marketers (outlet_id);
create index if not exists idx_marketers_status on public.marketers (status);
create index if not exists idx_marketer_targets_marketer_id on public.marketer_targets (marketer_id);
create index if not exists idx_marketer_targets_product_id on public.marketer_targets (product_id);
create index if not exists idx_marketer_targets_outlet_id on public.marketer_targets (outlet_id);
create index if not exists idx_marketer_targets_status on public.marketer_targets (status);
create index if not exists idx_marketer_targets_dates on public.marketer_targets (start_date, end_date);

-- Enable RLS (Row Level Security)
alter table public.marketers enable row level security;
alter table public.marketer_targets enable row level security;

-- Create RLS policies for marketers table
create policy "Enable read access for all users" on public.marketers
  for select using (true);

create policy "Enable insert for authenticated users only" on public.marketers
  for insert with check (auth.role() = 'authenticated');

create policy "Enable update for authenticated users only" on public.marketers
  for update using (auth.role() = 'authenticated');

create policy "Enable delete for authenticated users only" on public.marketers
  for delete using (auth.role() = 'authenticated');

-- Create RLS policies for marketer_targets table
create policy "Enable read access for all users" on public.marketer_targets
  for select using (true);

create policy "Enable insert for authenticated users only" on public.marketer_targets
  for insert with check (auth.role() = 'authenticated');

create policy "Enable update for authenticated users only" on public.marketer_targets
  for update using (auth.role() = 'authenticated');

create policy "Enable delete for authenticated users only" on public.marketer_targets
  for delete using (auth.role() = 'authenticated');