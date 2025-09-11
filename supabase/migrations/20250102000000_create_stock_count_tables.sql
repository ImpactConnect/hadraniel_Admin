-- Stock Count System Migration
-- This migration creates tables for stock counting and reconciliation functionality

-- Create stock_counts table
create table if not exists stock_counts (
  id uuid primary key default gen_random_uuid(),
  outlet_id uuid not null references outlets(id) on delete cascade,
  count_date timestamp with time zone not null default now(),
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'cancelled')),
  created_by uuid not null references profiles(id) on delete cascade,
  completed_at timestamp with time zone,
  notes text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- Create stock_count_items table
create table if not exists stock_count_items (
  id uuid primary key default gen_random_uuid(),
  stock_count_id uuid not null references stock_counts(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  product_name text not null,
  theoretical_quantity numeric(10,2) not null default 0,
  actual_quantity numeric(10,2) not null default 0,
  variance numeric(10,2) generated always as (actual_quantity - theoretical_quantity) stored,
  variance_percentage numeric(5,2) generated always as (
    case 
      when theoretical_quantity > 0 then ((actual_quantity - theoretical_quantity) / theoretical_quantity) * 100
      else 0
    end
  ) stored,
  cost_per_unit numeric(10,2) not null default 0,
  value_impact numeric(12,2) generated always as ((actual_quantity - theoretical_quantity) * cost_per_unit) stored,
  adjustment_reason text,
  notes text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- Create stock_adjustments table
create table if not exists stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  outlet_id uuid not null references outlets(id) on delete cascade,
  product_name text not null,
  outlet_name text not null,
  adjustment_quantity numeric(10,2) not null,
  adjustment_type text not null check (adjustment_type in ('increase', 'decrease')),
  reason text not null check (reason in ('damaged', 'theft', 'expired', 'counting_error', 'system_error', 'other')),
  reason_details text,
  cost_per_unit numeric(10,2) not null default 0,
  value_impact numeric(12,2) generated always as (adjustment_quantity * cost_per_unit) stored,
  created_by uuid not null references profiles(id) on delete cascade,
  approved_by uuid references profiles(id) on delete set null,
  approved_at timestamp with time zone,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  stock_count_id uuid references stock_counts(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- Create indexes for better performance
create index if not exists idx_stock_counts_outlet_id on stock_counts(outlet_id);
create index if not exists idx_stock_counts_status on stock_counts(status);
create index if not exists idx_stock_counts_count_date on stock_counts(count_date);
create index if not exists idx_stock_counts_created_by on stock_counts(created_by);

create index if not exists idx_stock_count_items_stock_count_id on stock_count_items(stock_count_id);
create index if not exists idx_stock_count_items_product_id on stock_count_items(product_id);
create index if not exists idx_stock_count_items_variance on stock_count_items(variance);

create index if not exists idx_stock_adjustments_product_id on stock_adjustments(product_id);
create index if not exists idx_stock_adjustments_outlet_id on stock_adjustments(outlet_id);
create index if not exists idx_stock_adjustments_status on stock_adjustments(status);
create index if not exists idx_stock_adjustments_created_by on stock_adjustments(created_by);
create index if not exists idx_stock_adjustments_stock_count_id on stock_adjustments(stock_count_id);
create index if not exists idx_stock_adjustments_created_at on stock_adjustments(created_at);

-- Create updated_at trigger function if it doesn't exist
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Create triggers for updated_at columns
create trigger update_stock_counts_updated_at
  before update on stock_counts
  for each row
  execute function update_updated_at_column();

create trigger update_stock_count_items_updated_at
  before update on stock_count_items
  for each row
  execute function update_updated_at_column();

create trigger update_stock_adjustments_updated_at
  before update on stock_adjustments
  for each row
  execute function update_updated_at_column();

-- Enable Row Level Security (RLS)
alter table stock_counts enable row level security;
alter table stock_count_items enable row level security;
alter table stock_adjustments enable row level security;

-- Create RLS policies

-- Stock Counts policies
create policy "Users can view stock counts for their outlets" on stock_counts
  for select using (
    outlet_id in (
      select outlet_id from profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

create policy "Users can create stock counts for their outlets" on stock_counts
  for insert with check (
    outlet_id in (
      select outlet_id from profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

create policy "Users can update stock counts for their outlets" on stock_counts
  for update using (
    outlet_id in (
      select outlet_id from profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

-- Stock Count Items policies
create policy "Users can view stock count items for their outlets" on stock_count_items
  for select using (
    stock_count_id in (
      select id from stock_counts where 
        outlet_id in (
          select outlet_id from profiles where id = auth.uid()
        ) or 
        exists (
          select 1 from profiles where id = auth.uid() and role = 'admin'
        )
    )
  );

create policy "Users can create stock count items for their outlets" on stock_count_items
  for insert with check (
    stock_count_id in (
      select id from stock_counts where 
        outlet_id in (
          select outlet_id from profiles where id = auth.uid()
        ) or 
        exists (
          select 1 from profiles where id = auth.uid() and role = 'admin'
        )
    )
  );

create policy "Users can update stock count items for their outlets" on stock_count_items
  for update using (
    stock_count_id in (
      select id from stock_counts where 
        outlet_id in (
          select outlet_id from profiles where id = auth.uid()
        ) or 
        exists (
          select 1 from profiles where id = auth.uid() and role = 'admin'
        )
    )
  );

-- Stock Adjustments policies
create policy "Users can view stock adjustments for their outlets" on stock_adjustments
  for select using (
    outlet_id in (
      select outlet_id from profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

create policy "Users can create stock adjustments for their outlets" on stock_adjustments
  for insert with check (
    outlet_id in (
      select outlet_id from profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

create policy "Users can update stock adjustments for their outlets" on stock_adjustments
  for update using (
    outlet_id in (
      select outlet_id from profiles where id = auth.uid()
    ) or 
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

-- Only admins can approve adjustments
create policy "Only admins can approve stock adjustments" on stock_adjustments
  for update using (
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  ) with check (
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

-- Create helpful views for reporting

-- Stock count summary view
create or replace view stock_count_summary as
select 
  sc.id,
  sc.outlet_id,
  o.name as outlet_name,
  sc.count_date,
  sc.status,
  sc.created_by,
  p.full_name as created_by_name,
  sc.completed_at,
  sc.notes,
  count(sci.id) as total_items,
  count(case when abs(sci.variance) > 0.01 then 1 end) as items_with_variance,
  sum(sci.value_impact) as total_value_impact,
  sc.created_at
from stock_counts sc
left join outlets o on sc.outlet_id = o.id
left join profiles p on sc.created_by = p.id
left join stock_count_items sci on sc.id = sci.stock_count_id
group by sc.id, o.name, p.full_name;

-- Stock variance analysis view
create or replace view stock_variance_analysis as
select 
  sci.id,
  sc.outlet_id,
  o.name as outlet_name,
  sci.product_id,
  sci.product_name,
  sci.theoretical_quantity,
  sci.actual_quantity,
  sci.variance,
  sci.variance_percentage,
  sci.value_impact,
  case 
    when abs(sci.variance) <= 0.01 then 'Match'
    when sci.variance > 0 then 'Overage'
    else 'Shortage'
  end as variance_status,
  case 
    when abs(sci.variance_percentage) > 10 then 'Critical'
    when abs(sci.variance_percentage) > 5 then 'Significant'
    when abs(sci.variance_percentage) > 1 then 'Minor'
    else 'Acceptable'
  end as variance_severity,
  sc.count_date,
  sc.status as count_status
from stock_count_items sci
join stock_counts sc on sci.stock_count_id = sc.id
join outlets o on sc.outlet_id = o.id;

-- Grant necessary permissions
grant usage on schema public to authenticated;
grant all on stock_counts to authenticated;
grant all on stock_count_items to authenticated;
grant all on stock_adjustments to authenticated;
grant select on stock_count_summary to authenticated;
grant select on stock_variance_analysis to authenticated;

-- Add comments for documentation
comment on table stock_counts is 'Stock counting sessions for inventory reconciliation';
comment on table stock_count_items is 'Individual product counts within a stock counting session';
comment on table stock_adjustments is 'Stock adjustments made to correct inventory discrepancies';
comment on view stock_count_summary is 'Summary view of stock counts with aggregated metrics';
comment on view stock_variance_analysis is 'Detailed analysis of stock variances with severity classification';