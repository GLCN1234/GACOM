-- ============================================================
-- GACOM Patch 9 SQL — Exco Inventory Manager Store Access
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── 1. Make sure exco users can SELECT their own assignment row ───────────────
-- This is what the Flutter _checkAdmin() reads to grant store access.
-- Without this, the query returns null even if the row exists.

DROP POLICY IF EXISTS "Exco can view their own assignment" ON public.exco_assignments;
CREATE POLICY "Exco can view their own assignment"
ON public.exco_assignments FOR SELECT
TO authenticated
USING (exco_id = auth.uid());

-- ── 2. Allow inventory_manager exco to INSERT products ───────────────────────
-- The store add-product form calls products.insert(). Without this policy
-- the insert will fail with 403 even if the Flutter button is visible.

DROP POLICY IF EXISTS "Inventory managers can add products" ON public.products;
CREATE POLICY "Inventory managers can add products"
ON public.products FOR INSERT
TO authenticated
WITH CHECK (
  -- Admins always can
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
  OR
  -- Inventory manager exco can
  EXISTS (SELECT 1 FROM public.exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'inventory_manager')
  OR
  -- Anyone selling their own product (seller_id = their id)
  auth.uid() = seller_id
);

-- ── 3. Allow inventory_manager exco to UPDATE products ───────────────────────
DROP POLICY IF EXISTS "Inventory managers can update products" ON public.products;
CREATE POLICY "Inventory managers can update products"
ON public.products FOR UPDATE
TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
  OR
  EXISTS (SELECT 1 FROM public.exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'inventory_manager')
  OR
  auth.uid() = seller_id
);

-- ── 4. Allow inventory_manager exco to DELETE products ───────────────────────
DROP POLICY IF EXISTS "Inventory managers can delete products" ON public.products;
CREATE POLICY "Inventory managers can delete products"
ON public.products FOR DELETE
TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
  OR
  EXISTS (SELECT 1 FROM public.exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'inventory_manager')
  OR
  auth.uid() = seller_id
);

-- ── 5. Make sure anyone can SELECT active products ────────────────────────────
DROP POLICY IF EXISTS "Anyone can view active products" ON public.products;
CREATE POLICY "Anyone can view active products"
ON public.products FOR SELECT
TO authenticated
USING (is_active = true OR auth.uid() = seller_id);

-- ── 6. Confirm products RLS is enabled ───────────────────────────────────────
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- ── 7. Product images storage bucket policies ──────────────────────────────────
-- Inventory managers also need to upload to product-images bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
CREATE POLICY "Anyone can view product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- ── VERIFY: run this to check the exco row exists after assigning ─────────────
-- SELECT * FROM exco_assignments WHERE exco_role = 'inventory_manager';
-- If empty, go to Admin → Exco & Roles and assign the user as Inventory Manager.
