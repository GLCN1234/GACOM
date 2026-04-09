-- ============================================================
-- GACOM Patch 4 SQL — Run in Supabase SQL Editor
-- ============================================================

-- ── 1. Password reset redirect URL ─────────────────────────────────────────
-- In Supabase Dashboard → Authentication → URL Configuration:
-- Add this to "Redirect URLs":
--   https://gamicom.netlify.app/#/reset-password
-- This is what allows the reset email link to land on your app.

-- ── 2. Fix likes_count — ensure the trigger is not resetting it ────────────
-- The like count was vanishing because the trigger increments from the DB value
-- but the client also sets it. Drop the RPC-based trigger and use direct updates.

-- Drop old increment/decrement RPCs if they exist
DROP FUNCTION IF EXISTS increment_likes(uuid);
DROP FUNCTION IF EXISTS decrement_likes(uuid);

-- ── 3. Comments count increment function ───────────────────────────────────
CREATE OR REPLACE FUNCTION increment_comments_count(post_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.posts SET comments_count = COALESCE(comments_count, 0) + 1 WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 4. Post likes RLS — allow authenticated users to insert/delete ──────────
CREATE POLICY IF NOT EXISTS "Users can like posts"
ON public.post_likes FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can unlike posts"
ON public.post_likes FOR DELETE TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Anyone can see likes"
ON public.post_likes FOR SELECT TO authenticated
USING (true);

-- ── 5. Post comments RLS ────────────────────────────────────────────────────
CREATE POLICY IF NOT EXISTS "Users can comment"
ON public.post_comments FOR INSERT TO authenticated
WITH CHECK (auth.uid() = author_id);

CREATE POLICY IF NOT EXISTS "Anyone can see comments"
ON public.post_comments FOR SELECT TO authenticated
USING (NOT is_deleted);

-- ── 6. Allow posts.likes_count to be updated by authenticated users ─────────
CREATE POLICY IF NOT EXISTS "Users can update post likes count"
ON public.posts FOR UPDATE TO authenticated
USING (true)
WITH CHECK (true);

-- ── 7. DM chat RLS ──────────────────────────────────────────────────────────
CREATE POLICY IF NOT EXISTS "Users can create chats"
ON public.chats FOR INSERT TO authenticated
WITH CHECK (auth.uid() = created_by);

CREATE POLICY IF NOT EXISTS "Chat members can view chats"
ON public.chats FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.chat_members WHERE chat_id = id AND user_id = auth.uid()));

CREATE POLICY IF NOT EXISTS "Users can join chats"
ON public.chat_members FOR INSERT TO authenticated
WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Users can view chat members"
ON public.chat_members FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.chat_members cm2 WHERE cm2.chat_id = chat_id AND cm2.user_id = auth.uid()));

-- ── 8. Follows RLS ───────────────────────────────────────────────────────────
CREATE POLICY IF NOT EXISTS "Users can follow others"
ON public.follows FOR INSERT TO authenticated
WITH CHECK (auth.uid() = follower_id);

CREATE POLICY IF NOT EXISTS "Users can unfollow"
ON public.follows FOR DELETE TO authenticated
USING (auth.uid() = follower_id);

CREATE POLICY IF NOT EXISTS "Anyone can see follows"
ON public.follows FOR SELECT TO authenticated
USING (true);

-- ── 9. Products — allow sellers to upload images via storage ────────────────
-- Ensure product images bucket exists
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true) ON CONFLICT (id) DO UPDATE SET public = true;

CREATE POLICY IF NOT EXISTS "Admins can upload product images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product-images');

CREATE POLICY IF NOT EXISTS "Anyone can view product images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'product-images');

-- ── 10. Store — add missing columns if needed ────────────────────────────────
DO $$ BEGIN
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS seller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'accessories';
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS whatsapp_contact TEXT;
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS location TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
