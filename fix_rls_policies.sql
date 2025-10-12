-- =====================================================
-- RLS Policies: Grant read/insert/update to all authenticated users,
-- restrict delete to admins only (role in public.profiles)
-- Execute this script in your Supabase SQL Editor
-- =====================================================

-- =====================================================
-- Products table policies
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can view all products" ON public.products;
DROP POLICY IF EXISTS "Users can view products for their outlets" ON public.products;
DROP POLICY IF EXISTS "Products access policy" ON public.products;
DROP POLICY IF EXISTS "Authenticated SELECT (products)" ON public.products;
DROP POLICY IF EXISTS "Authenticated INSERT (products)" ON public.products;
DROP POLICY IF EXISTS "Authenticated UPDATE (products)" ON public.products;
DROP POLICY IF EXISTS "Admin DELETE (products)" ON public.products;

-- Grant read to all authenticated
CREATE POLICY "Authenticated SELECT (products)"
  ON public.products
  FOR SELECT
  TO authenticated
  USING (true);

-- Grant insert to all authenticated
CREATE POLICY "Authenticated INSERT (products)"
  ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Grant update to all authenticated
CREATE POLICY "Authenticated UPDATE (products)"
  ON public.products
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Restrict delete to admins only
CREATE POLICY "Admin DELETE (products)"
  ON public.products
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- =====================================================
-- Stock balances table policies
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE public.stock_balances ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can view all stock balances" ON public.stock_balances;
DROP POLICY IF EXISTS "Users can view stock balances for their outlets" ON public.stock_balances;
DROP POLICY IF EXISTS "Stock balances access policy" ON public.stock_balances;
DROP POLICY IF EXISTS "Authenticated SELECT (stock_balances)" ON public.stock_balances;
DROP POLICY IF EXISTS "Authenticated INSERT (stock_balances)" ON public.stock_balances;
DROP POLICY IF EXISTS "Authenticated UPDATE (stock_balances)" ON public.stock_balances;
DROP POLICY IF EXISTS "Admin DELETE (stock_balances)" ON public.stock_balances;

-- Grant read to all authenticated
CREATE POLICY "Authenticated SELECT (stock_balances)"
  ON public.stock_balances
  FOR SELECT
  TO authenticated
  USING (true);

-- Grant insert to all authenticated
CREATE POLICY "Authenticated INSERT (stock_balances)"
  ON public.stock_balances
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Grant update to all authenticated
CREATE POLICY "Authenticated UPDATE (stock_balances)"
  ON public.stock_balances
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Restrict delete to admins only
CREATE POLICY "Admin DELETE (stock_balances)"
  ON public.stock_balances
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Remove hardcoded admin UID override (replaced by role-based delete policy)

-- =====================================================
-- Sale items table policies
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can view all sale items" ON public.sale_items;
DROP POLICY IF EXISTS "Users can view sale items for their outlets" ON public.sale_items;
DROP POLICY IF EXISTS "Sale items access policy" ON public.sale_items;
DROP POLICY IF EXISTS "Authenticated SELECT (sale_items)" ON public.sale_items;
DROP POLICY IF EXISTS "Authenticated INSERT (sale_items)" ON public.sale_items;
DROP POLICY IF EXISTS "Authenticated UPDATE (sale_items)" ON public.sale_items;
DROP POLICY IF EXISTS "Admin DELETE (sale_items)" ON public.sale_items;

-- Grant read to all authenticated
CREATE POLICY "Authenticated SELECT (sale_items)"
  ON public.sale_items
  FOR SELECT
  TO authenticated
  USING (true);

-- Grant insert to all authenticated
CREATE POLICY "Authenticated INSERT (sale_items)"
  ON public.sale_items
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Grant update to all authenticated
CREATE POLICY "Authenticated UPDATE (sale_items)"
  ON public.sale_items
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Restrict delete to admins only
CREATE POLICY "Admin DELETE (sale_items)"
  ON public.sale_items
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Base grants (required in addition to policies)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_balances TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.sale_items TO authenticated;

-- =====================================================
-- Test the policies
-- =====================================================

-- Test 1: Check if current user can access products
DO $$
DECLARE
    product_count INTEGER;
    current_user_id UUID;
    user_role TEXT;
BEGIN
    -- Get current user info
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ No authenticated user found';
        RETURN;
    END IF;
    
    -- Get user role
    SELECT role INTO user_role FROM public.profiles WHERE id = current_user_id;
    RAISE NOTICE '👤 Current user role: %', COALESCE(user_role, 'unknown');
    
    -- Test products access
    SELECT COUNT(*) INTO product_count FROM public.products;
    RAISE NOTICE '📦 Products accessible: % records', product_count;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error testing policies: %', SQLERRM;
END $$;

-- =====================================================
-- Verification queries
-- =====================================================

SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('products', 'stock_balances', 'sale_items');

SELECT 
    schemaname,
    tablename,
    policyname,
    cmd as operation,
    roles
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('products', 'stock_balances', 'sale_items')
ORDER BY tablename, cmd;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies updated!';
    RAISE NOTICE '🔧 Read/Insert/Update open to authenticated users; Delete restricted to admins';
    RAISE NOTICE '📋 Products, stock_balances, and sale_items tables updated';
END $$;