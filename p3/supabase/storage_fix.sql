-- ============================================================
-- GACOM Storage & Post Fix — Run in Supabase SQL Editor
-- ============================================================

-- 1. The post-media bucket 400 error comes from missing RLS policy.
--    Run this to allow authenticated users to upload to post-media:

-- First make sure the bucket exists (run in Storage UI if it doesn't)
-- Bucket name: post-media, public: true

-- Storage RLS policies for post-media bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-media', 'post-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow authenticated users to upload to post-media
CREATE POLICY "Authenticated users can upload post media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'post-media');

CREATE POLICY "Anyone can view post media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'post-media');

CREATE POLICY "Users can delete own post media"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'post-media' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Avatar bucket policies
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Anyone can view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- 2. Post detail route — add a post_detail table view
-- The profile grid needs a post ID to navigate to post detail
-- Posts already have IDs, just need the route + screen

-- 3. Ensure posts RLS allows insert by authenticated users
CREATE POLICY IF NOT EXISTS "Users can insert own posts"
ON public.posts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = author_id);
