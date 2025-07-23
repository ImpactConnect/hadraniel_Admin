# Stock Intake Sync Setup Guide

## Issue
The stock intake screen cannot fetch data from the cloud database because the required Supabase tables (`stock_intake` and `intake_balances`) do not exist.

## Solution

### Step 1: Create Supabase Tables
You need to run the migration file to create the required tables in your Supabase database.

#### Option A: Using Supabase CLI (Recommended)
1. Install Supabase CLI if you haven't already:
   ```bash
   npm install -g supabase
   ```

2. Navigate to your project directory:
   ```bash
   cd c:\Users\HP\Desktop\hadraniel_Admin
   ```

3. Run the migration:
   ```bash
   supabase db push
   ```

#### Option B: Manual SQL Execution
1. Open your Supabase dashboard
2. Go to the SQL Editor
3. Copy and paste the contents of `supabase/migrations/20240301000000_create_stock_intake_tables.sql`
4. Execute the SQL

### Step 2: Verify Tables Creation
After running the migration, verify that the following tables exist in your Supabase database:
- `public.stock_intake`
- `public.intake_balances`

### Step 3: Test the Sync
1. Open the stock intake screen in your app
2. Try adding a new stock intake record
3. Click the sync button to test bidirectional syncing
4. Check the console logs for any error messages

## What the Migration Creates

### stock_intake table
- `id` (UUID, Primary Key)
- `product_name` (Text, Not Null)
- `quantity_received` (Real, Not Null)
- `unit` (Text, Not Null)
- `cost_per_unit` (Real, Not Null)
- `total_cost` (Real, Not Null)
- `description` (Text, Optional)
- `date_received` (Timestamp, Not Null)
- `created_at` (Timestamp, Default: now())

### intake_balances table
- `id` (UUID, Primary Key)
- `product_name` (Text, Not Null)
- `total_received` (Real, Not Null)
- `total_assigned` (Real, Default: 0)
- `balance_quantity` (Real, Not Null)
- `last_updated` (Timestamp, Default: now())

## Row Level Security (RLS)
Both tables have RLS enabled with policies that allow:
- Admins to view, insert, and update all records
- Proper security for multi-tenant usage

## Troubleshooting

### Error: "relation 'public.stock_intake' does not exist"
This means the migration hasn't been applied yet. Follow Step 1 above.

### Error: "Error syncing stock intake to Supabase"
Check your Supabase connection and ensure you have admin privileges.

### No data appears after sync
Ensure you have data in your Supabase tables and that your user has the 'admin' role in the profiles table.

## Console Log Messages
After applying the fix, you should see these messages in the console:
- `Successfully synced X stock intakes from Supabase`
- `Successfully synced X intake balances from Supabase`

If you see error messages about missing tables, the migration needs to be applied.