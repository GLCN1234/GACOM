-- =============================================================
-- GACOM PATCH: Fix all missing RLS policies + storage + helpers
-- Run this in Supabase SQL Editor (it is idempotent)
-- =============================================================

-- ── 1. COMPETITIONS: missing INSERT/UPDATE/DELETE policies ────────────────────
-- Root cause of POST competitions → 403 Forbidden

DO $$ BEGIN
  -- Drop existing competition policies if any (clean slate)
  DROP POLICY IF EXISTS "Anyone can view competitions" ON competitions;
  DROP POLICY IF EXISTS "Admins can create competitions" ON competitions;
  DROP POLICY IF EXISTS "Permitted users can create competitions" ON competitions;
  DROP POLICY IF EXISTS "Admins can update competitions" ON competitions;
  DROP POLICY IF EXISTS "Admins can delete competitions" ON competitions;
END $$;

CREATE POLICY "Anyone can view competitions"
  ON competitions FOR SELECT USING (true);

-- Admins OR users with create_competitions permission can insert
CREATE POLICY "Permitted users can create competitions"
  ON competitions FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
    AND (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'super_admin')
      )
      OR EXISTS (
        SELECT 1 FROM admin_permissions
        WHERE admin_id = auth.uid()
        AND permission = 'create_competitions'
      )
    )
  );

CREATE POLICY "Admins can update competitions"
  ON competitions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Admins can delete competitions"
  ON competitions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );


-- ── 2. COMMUNITIES: missing INSERT/UPDATE policies ────────────────────────────
-- Root cause of POST communities → 403 Forbidden

DO $$ BEGIN
  DROP POLICY IF EXISTS "Anyone can view communities" ON communities;
  DROP POLICY IF EXISTS "Verified users and admins can create communities" ON communities;
  DROP POLICY IF EXISTS "Admins can update communities" ON communities;
  DROP POLICY IF EXISTS "Admins can delete communities" ON communities;
  DROP POLICY IF EXISTS "Community members can view" ON community_members;
  DROP POLICY IF EXISTS "Users can join communities" ON community_members;
  DROP POLICY IF EXISTS "Users can leave communities" ON community_members;
END $$;

CREATE POLICY "Anyone can view communities"
  ON communities FOR SELECT USING (is_active = true);

-- Verified users + admins can create (sub-)communities
CREATE POLICY "Verified users and admins can create communities"
  ON communities FOR INSERT
  WITH CHECK (
    auth.uid() = created_by
    AND (
      EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND (
          role IN ('admin', 'super_admin')
          OR verification_status = 'verified'
        )
      )
    )
  );

CREATE POLICY "Admins can update communities"
  ON communities FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
    OR auth.uid() = created_by
  );

CREATE POLICY "Admins can delete communities"
  ON communities FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

-- Community members policies
CREATE POLICY "Community members can view"
  ON community_members FOR SELECT USING (true);

CREATE POLICY "Users can join communities"
  ON community_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave communities"
  ON community_members FOR DELETE
  USING (auth.uid() = user_id);


-- ── 3. ADMIN PERMISSIONS: policies ───────────────────────────────────────────

DO $$ BEGIN
  DROP POLICY IF EXISTS "Admins manage permissions" ON admin_permissions;
  DROP POLICY IF EXISTS "Users see own permissions" ON admin_permissions;
END $$;

ALTER TABLE admin_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage permissions"
  ON admin_permissions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Users see own permissions"
  ON admin_permissions FOR SELECT
  USING (admin_id = auth.uid());


-- ── 4. STORAGE: post-media bucket setup ──────────────────────────────────────
-- Create bucket if not exists + add upload/read policies

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post-media',
  'post-media',
  true,
  52428800, -- 50MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800;

-- Drop old storage policies
DO $$ BEGIN
  DROP POLICY IF EXISTS "Authenticated users upload post media" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view post media" ON storage.objects;
  DROP POLICY IF EXISTS "Users delete own post media" ON storage.objects;
END $$;

CREATE POLICY "Authenticated users upload post media"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'post-media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Anyone can view post media"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'post-media');

CREATE POLICY "Users delete own post media"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'post-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- avatars bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Authenticated users upload avatars" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
END $$;

CREATE POLICY "Authenticated users upload avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Anyone can view avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');


-- ── 5. NEW TABLES: exco_assignments, support_tickets, support_messages, etc. ──

-- exco_assignments
CREATE TABLE IF NOT EXISTS exco_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exco_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  exco_role TEXT NOT NULL,
  assigned_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(exco_id)
);

ALTER TABLE exco_assignments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Admins manage exco" ON exco_assignments;
  DROP POLICY IF EXISTS "Exco see own assignment" ON exco_assignments;
END $$;

CREATE POLICY "Admins manage exco"
  ON exco_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

CREATE POLICY "Exco see own assignment"
  ON exco_assignments FOR SELECT
  USING (exco_id = auth.uid());

-- Add exco_role column to profiles if not exists
DO $$ BEGIN
  ALTER TABLE profiles ADD COLUMN IF NOT EXISTS exco_role TEXT;
END $$;

-- support_tickets
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  issue TEXT,
  status TEXT DEFAULT 'open',
  conversation JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users manage own tickets" ON support_tickets;
  DROP POLICY IF EXISTS "Agents see assigned tickets" ON support_tickets;
  DROP POLICY IF EXISTS "Admins see all tickets" ON support_tickets;
END $$;

CREATE POLICY "Users manage own tickets"
  ON support_tickets FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Agents see assigned tickets"
  ON support_tickets FOR SELECT
  USING (auth.uid() = agent_id);

CREATE POLICY "Admins see all tickets"
  ON support_tickets FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

-- support_messages
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id UUID REFERENCES support_tickets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  agent_id UUID REFERENCES profiles(id),
  sender_id UUID REFERENCES profiles(id),
  content TEXT NOT NULL,
  is_from_user BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Ticket participants see messages" ON support_messages;
  DROP POLICY IF EXISTS "Ticket participants send messages" ON support_messages;
END $$;

CREATE POLICY "Ticket participants see messages"
  ON support_messages FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = agent_id);

CREATE POLICY "Ticket participants send messages"
  ON support_messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- bug_reports
CREATE TABLE IF NOT EXISTS bug_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  description TEXT NOT NULL,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users create bug reports" ON bug_reports;
  DROP POLICY IF EXISTS "Admins see bug reports" ON bug_reports;
END $$;

CREATE POLICY "Users create bug reports"
  ON bug_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins see bug reports"
  ON bug_reports FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

-- withdrawal_requests (for Finance section in admin)
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount DECIMAL(15,2) NOT NULL,
  bank_name TEXT,
  account_number TEXT,
  account_name TEXT,
  status TEXT DEFAULT 'pending',
  processed_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "Users manage own withdrawals" ON withdrawal_requests;
  DROP POLICY IF EXISTS "Admins manage withdrawals" ON withdrawal_requests;
END $$;

CREATE POLICY "Users manage own withdrawals"
  ON withdrawal_requests FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Admins manage withdrawals"
  ON withdrawal_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );


-- ── 6. HELPER: get_user_id_by_email function ────────────────────────────────
-- Used by admin to assign exco by email

CREATE OR REPLACE FUNCTION get_user_id_by_email(email TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id UUID;
BEGIN
  SELECT id INTO user_id
  FROM auth.users
  WHERE auth.users.email = get_user_id_by_email.email
  LIMIT 1;
  RETURN user_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_user_id_by_email(TEXT) TO authenticated;


-- ── 7. increment_posts_count function ────────────────────────────────────────

CREATE OR REPLACE FUNCTION increment_posts_count(user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET posts_count = posts_count + 1
  WHERE id = user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_posts_count(UUID) TO authenticated;


-- ── 8. PRODUCTS: INSERT policy (sellers can list) ─────────────────────────────

DO $$ BEGIN
  DROP POLICY IF EXISTS "Verified sellers can list products" ON products;
  DROP POLICY IF EXISTS "Sellers can update own products" ON products;
  DROP POLICY IF EXISTS "Sellers can delete own products" ON products;
END $$;

CREATE POLICY "Verified sellers can list products"
  ON products FOR INSERT
  WITH CHECK (
    auth.uid() = seller_id
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND (
        verification_status = 'verified'
        OR role IN ('admin', 'super_admin')
      )
    )
  );

CREATE POLICY "Sellers can update own products"
  ON products FOR UPDATE
  USING (auth.uid() = seller_id);

CREATE POLICY "Sellers can delete own products"
  ON products FOR DELETE
  USING (auth.uid() = seller_id);


-- ── 9. profiles SELECT: make email accessible to admins ──────────────────────
-- The admin dashboard was querying 'email' which doesn't exist in profiles.
-- We expose it via a view for admins. But for now the dashboard is fixed
-- to not query email from profiles (email lives in auth.users).

-- Realtime for new tables
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE support_messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE support_tickets;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
