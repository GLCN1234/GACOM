-- ============================================================
-- GACOM Patch 5 SQL — Run in Supabase SQL Editor
-- ============================================================

-- ── 1. get_user_id_by_email function (FIXES exco assignment) ────────────────
-- This allows admins to look up a user's profile ID by their auth email.
-- Runs as SECURITY DEFINER so it can access auth.users.
CREATE OR REPLACE FUNCTION public.get_user_id_by_email(email TEXT)
RETURNS TEXT AS $$
DECLARE
  result_id UUID;
BEGIN
  SELECT id INTO result_id FROM auth.users WHERE auth.users.email = get_user_id_by_email.email LIMIT 1;
  RETURN result_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execute to authenticated users so the client SDK can call it
GRANT EXECUTE ON FUNCTION public.get_user_id_by_email(TEXT) TO authenticated;

-- ── 2. exco_assignments table — ensure it exists with right schema ────────────
CREATE TABLE IF NOT EXISTS public.exco_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exco_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  exco_role TEXT NOT NULL,
  assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(exco_id, exco_role)
);

ALTER TABLE public.exco_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Admins manage exco assignments"
ON public.exco_assignments FOR ALL
TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

CREATE POLICY IF NOT EXISTS "Exco can view their own assignment"
ON public.exco_assignments FOR SELECT
TO authenticated
USING (exco_id = auth.uid());

-- ── 3. Blog posts RLS — allow exco blog_editors + admins to insert/update ────
-- First check if policy exists and drop if needed
DROP POLICY IF EXISTS "Exco blog editors can manage posts" ON public.blog_posts;

CREATE POLICY "Exco blog editors can manage posts" ON public.blog_posts
FOR ALL TO authenticated
USING (
  auth.uid() = author_id OR
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')) OR
  EXISTS (SELECT 1 FROM public.exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'blog_editor') OR
  EXISTS (SELECT 1 FROM public.admin_permissions WHERE admin_id = auth.uid() AND permission = 'manage_blog')
);

-- Allow published blog posts to be read by anyone
CREATE POLICY IF NOT EXISTS "Anyone can read published blogs"
ON public.blog_posts FOR SELECT TO public
USING (is_published = true);

-- ── 4. Fix notifications table RLS for competition notifications ──────────────
CREATE POLICY IF NOT EXISTS "Users see own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (recipient_id = auth.uid());

CREATE POLICY IF NOT EXISTS "System can insert notifications"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (true);

-- ── 5. Profiles — ensure no 'email' select causes issues ─────────────────────
-- The profile queries must NOT select 'email' — it doesn't exist on profiles.
-- This is purely a reminder — no SQL needed.
-- The Flutter code has been updated to not select 'email' from profiles.

-- ── 6. Admin permissions for blog_editor exco ─────────────────────────────────
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Admins manage permissions"
ON public.admin_permissions FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- ── 7. Realtime for exco_assignments ─────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.exco_assignments;
