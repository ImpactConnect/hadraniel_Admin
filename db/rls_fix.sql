-- Consolidate SELECT RLS policies for products and stock_balances
-- Uses role from public.profiles to grant admin full access
-- and non-admins access scoped to their outlet_id

-- Ensure RLS is enabled (already true per your screenshot; safe to re-run)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_balances ENABLE ROW LEVEL SECURITY;

-- Drop existing SELECT policies to avoid conflicts
DROP POLICY IF EXISTS "Products access policy" ON public.products;
DROP POLICY IF EXISTS "Admin UID can view all products" ON public.products;
DROP POLICY IF EXISTS "Stock balances access policy" ON public.stock_balances;
DROP POLICY IF EXISTS "Admin UID can view all stock_balances" ON public.stock_balances;

-- Create consolidated SELECT policy for products
CREATE POLICY "Authenticated SELECT with admin override (products)"
ON public.products
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
  OR (
    outlet_id = (
      SELECT p.outlet_id FROM public.profiles p WHERE p.id = auth.uid()
    )
  )
);

-- Create consolidated SELECT policy for stock_balances
CREATE POLICY "Authenticated SELECT with admin override (stock_balances)"
ON public.stock_balances
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
  OR (
    outlet_id = (
      SELECT p.outlet_id FROM public.profiles p WHERE p.id = auth.uid()
    )
  )
);

-- Optional: Verify policies
-- SELECT schemaname, tablename, policyname, cmd, roles
-- FROM pg_policies WHERE schemaname='public' AND tablename IN ('products','stock_balances')
-- ORDER BY tablename, cmd;