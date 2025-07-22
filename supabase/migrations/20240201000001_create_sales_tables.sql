-- Create sales table
create table if not exists public.sales (
  id uuid primary key,
  outlet_id uuid not null references public.outlets(id),
  customer_id uuid references public.customers(id),
  rep_id uuid references public.profiles(id),
  vat real default 0,
  total_amount real default 0,
  amount_paid real default 0,
  outstanding_amount real default 0,
  is_paid boolean default false,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create sale_items table
create table if not exists public.sale_items (
  id uuid primary key,
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity real not null,
  unit_price real not null,
  total real not null,
  created_at timestamp with time zone default now()
);

-- Create indexes for better query performance
create index if not exists idx_sales_outlet_id on public.sales(outlet_id);
create index if not exists idx_sales_customer_id on public.sales(customer_id);
create index if not exists idx_sales_rep_id on public.sales(rep_id);
create index if not exists idx_sales_created_at on public.sales(created_at);
create index if not exists idx_sale_items_sale_id on public.sale_items(sale_id);
create index if not exists idx_sale_items_product_id on public.sale_items(product_id);