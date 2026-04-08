-- ============================================================
-- GACOM Bug Fix Migration — Run in Supabase SQL Editor
-- Fixes: wallet_transactions 403, products 400, video upload 400
-- ============================================================

-- ── FIX 1: wallet_transactions 403 ───────────────────────────────────────────
-- Missing INSERT policy caused 403 when recording transactions.
-- Safe to run multiple times.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'wallet_transactions'
    AND policyname = 'Users can insert own transactions'
  ) THEN
    EXECUTE 'CREATE POLICY "Users can insert own transactions"
      ON wallet_transactions FOR INSERT
      WITH CHECK (auth.uid() = user_id)';
  END IF;
END $$;

-- Allow users to update their own transactions (e.g. status from pending→success)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'wallet_transactions'
    AND policyname = 'Users can update own transactions'
  ) THEN
    EXECUTE 'CREATE POLICY "Users can update own transactions"
      ON wallet_transactions FOR UPDATE
      USING (auth.uid() = user_id)';
  END IF;
END $$;

-- Allow admins to view all transactions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'wallet_transactions'
    AND policyname = 'Admins can view all transactions'
  ) THEN
    EXECUTE 'CREATE POLICY "Admins can view all transactions"
      ON wallet_transactions FOR SELECT
      USING (
        auth.uid() IN (
          SELECT id FROM profiles WHERE role IN (''admin'', ''super_admin'')
        )
      )';
  END IF;
END $$;


-- ── FIX 2: products 400 (is_available column missing) ────────────────────────
-- Schema uses is_active but code queries is_available.
-- Add a generated column as an alias so both work.

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS is_available BOOLEAN
  GENERATED ALWAYS AS (is_active) STORED;


-- ── FIX 3: withdrawal_requests INSERT policy ─────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'withdrawal_requests'
    AND policyname = 'Users can insert own withdrawal requests'
  ) THEN
    EXECUTE 'CREATE POLICY "Users can insert own withdrawal requests"
      ON withdrawal_requests FOR INSERT
      WITH CHECK (auth.uid() = user_id)';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'withdrawal_requests'
    AND policyname = 'Users can view own withdrawal requests'
  ) THEN
    EXECUTE 'CREATE POLICY "Users can view own withdrawal requests"
      ON withdrawal_requests FOR SELECT
      USING (auth.uid() = user_id)';
  END IF;
END $$;


-- ── FIX 4: post_media uploads — ensure RLS on storage ────────────────────────
-- Run these only if the buckets exist and policies are missing.

INSERT INTO storage.buckets (id, name, public)
  VALUES ('post-media', 'post-media', true)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars', 'avatars', true)
  ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload to post-media
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
    AND policyname = 'Auth users can upload post media'
  ) THEN
    EXECUTE 'CREATE POLICY "Auth users can upload post media"
      ON storage.objects FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = ''post-media'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
    AND policyname = 'Post media is public'
  ) THEN
    EXECUTE 'CREATE POLICY "Post media is public"
      ON storage.objects FOR SELECT
      TO public
      USING (bucket_id = ''post-media'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
    AND policyname = 'Auth users can upload avatars'
  ) THEN
    EXECUTE 'CREATE POLICY "Auth users can upload avatars"
      ON storage.objects FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = ''avatars'')';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
    AND policyname = 'Avatars are public'
  ) THEN
    EXECUTE 'CREATE POLICY "Avatars are public"
      ON storage.objects FOR SELECT
      TO public
      USING (bucket_id = ''avatars'')';
  END IF;
END $$;


-- ── FIX 5: add_wallet_balance RPC (called from Flutter after payment) ────────
CREATE OR REPLACE FUNCTION add_wallet_balance(p_user_id UUID, p_amount DECIMAL)
RETURNS void AS $$
  UPDATE profiles
  SET wallet_balance = COALESCE(wallet_balance, 0) + p_amount
  WHERE id = p_user_id;
$$ LANGUAGE sql SECURITY DEFINER;


-- ── Verification: check what was applied ─────────────────────────────────────
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('wallet_transactions', 'withdrawal_requests', 'products')
ORDER BY tablename, cmd;
