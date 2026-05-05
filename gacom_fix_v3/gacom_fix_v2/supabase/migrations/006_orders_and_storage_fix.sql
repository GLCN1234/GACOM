-- ============================================================
-- GACOM Store Fix: Orders table + Storage bucket policy
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Orders table (stores cart checkout results)
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  reference TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
  subtotal DECIMAL(10,2) NOT NULL,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  total DECIMAL(10,2) NOT NULL,
  delivery_state TEXT,
  delivery_days TEXT,
  items JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. RLS for orders
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own orders" ON orders;
CREATE POLICY "Users can view own orders"
  ON orders FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own orders" ON orders;
CREATE POLICY "Users can create own orders"
  ON orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all orders" ON orders;
CREATE POLICY "Admins can view all orders"
  ON orders FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

-- 3. Also add seller_id to products if it doesn't exist
--    (needed so sellers can see their own products in MY LISTINGS)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'seller_id'
  ) THEN
    ALTER TABLE products ADD COLUMN seller_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 4. Also add category as a plain text column (the app uses it as string, not FK)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'category'
  ) THEN
    ALTER TABLE products ADD COLUMN category TEXT DEFAULT 'accessories';
  END IF;
END $$;

-- 5. Make product-images bucket PUBLIC so uploaded images render in the app
--    Run this in Storage > Buckets > product-images > Edit > make Public
--    OR run the SQL below:
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 6. Storage RLS: allow authenticated users to upload to product-images
DROP POLICY IF EXISTS "Allow authenticated uploads to product-images" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to product-images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "Allow public read of product-images" ON storage.objects;
CREATE POLICY "Allow public read of product-images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');
