-- =====================================================
-- RLS Policies Setup for Existing Tables
-- Execute this script in your Supabase SQL Editor
-- 
-- NOTE: This script assumes tables already exist with live data
-- =====================================================

-- Verify tables exist before proceeding
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products') THEN
        RAISE EXCEPTION 'Products table does not exist. Please create it first.';
    END IF;
    
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'stock_balances') THEN
        RAISE EXCEPTION 'Stock_balances table does not exist. Please create it first.';
    END IF;
    
    RAISE NOTICE '✅ Both tables exist. Proceeding with RLS setup...';
END $$;

-- =====================================================
-- Enable RLS for products table
-- =====================================================

-- Enable RLS for products table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Admins can view all products" ON public.products;
DROP POLICY IF EXISTS "Admins can insert products" ON public.products;
DROP POLICY IF EXISTS "Admins can update products" ON public.products;
DROP POLICY IF EXISTS "Admins can delete products" ON public.products;
DROP POLICY IF EXISTS "Users can view products for their outlets" ON public.products;

-- Create policy for admins to view all products
CREATE POLICY "Admins can view all products"
  ON public.products
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for admins to insert products
CREATE POLICY "Admins can insert products"
  ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for admins to update products
CREATE POLICY "Admins can update products"
  ON public.products
  FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for admins to delete products
CREATE POLICY "Admins can delete products"
  ON public.products
  FOR DELETE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for users to view products for their outlets
CREATE POLICY "Users can view products for their outlets"
  ON public.products
  FOR SELECT
  TO authenticated
  USING (
    outlet_id IN (
      SELECT outlet_id FROM public.profiles WHERE id = auth.uid()
    ) OR 
    EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- Enable RLS for stock_balances table
-- =====================================================

-- Enable RLS for stock_balances table
ALTER TABLE public.stock_balances ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Admins can view all stock balances" ON public.stock_balances;
DROP POLICY IF EXISTS "Admins can insert stock balances" ON public.stock_balances;
DROP POLICY IF EXISTS "Admins can update stock balances" ON public.stock_balances;
DROP POLICY IF EXISTS "Admins can delete stock balances" ON public.stock_balances;
DROP POLICY IF EXISTS "Users can view stock balances for their outlets" ON public.stock_balances;
DROP POLICY IF EXISTS "Users can update stock balances for their outlets" ON public.stock_balances;

-- Create policy for admins to view all stock balances
CREATE POLICY "Admins can view all stock balances"
  ON public.stock_balances
  FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for admins to insert stock balances
CREATE POLICY "Admins can insert stock balances"
  ON public.stock_balances
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for admins to update stock balances
CREATE POLICY "Admins can update stock balances"
  ON public.stock_balances
  FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for admins to delete stock balances
CREATE POLICY "Admins can delete stock balances"
  ON public.stock_balances
  FOR DELETE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Create policy for users to view stock balances for their outlets
CREATE POLICY "Users can view stock balances for their outlets"
  ON public.stock_balances
  FOR SELECT
  TO authenticated
  USING (
    outlet_id IN (
      SELECT outlet_id FROM public.profiles WHERE id = auth.uid()
    ) OR 
    EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Create policy for users to update stock balances for their outlets
CREATE POLICY "Users can update stock balances for their outlets"
  ON public.stock_balances
  FOR UPDATE
  TO authenticated
  USING (
    outlet_id IN (
      SELECT outlet_id FROM public.profiles WHERE id = auth.uid()
    ) OR 
    EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- Verification queries
-- =====================================================

-- Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('products', 'stock_balances');

-- List all policies for products table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'products';

-- List all policies for stock_balances table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'stock_balances';

-- =====================================================
-- Success message
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ RLS setup completed successfully!';
    RAISE NOTICE '📋 Tables configured: products, stock_balances';
    RAISE NOTICE '🔒 RLS policies created for admin and user access';
    RAISE NOTICE '🔍 Run the verification queries above to confirm setup';
END $$;