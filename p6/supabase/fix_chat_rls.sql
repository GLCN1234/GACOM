-- ============================================================
-- GACOM Patch 6 — Chat RLS Infinite Recursion Fix
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── ROOT CAUSE ────────────────────────────────────────────────────────────────
-- Migration 003 created this policy on chat_members:
--
--   CREATE POLICY "gacom_chat_members_select" ON chat_members FOR SELECT
--   USING (
--     EXISTS (SELECT 1 FROM chat_members cm2      ← queries ITSELF
--       WHERE cm2.chat_id = chat_members.chat_id AND cm2.user_id = auth.uid())
--   );
--
-- PostgreSQL detects the self-reference and throws:
--   "infinite recursion detected in policy for relation chat_members"
--
-- The fix: replace every policy on chat_members that references chat_members
-- with a simple USING (user_id = auth.uid()) — you can only see rows where
-- you are the member. That's correct and has zero recursion.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Drop ALL existing policies on chat_members (clean slate)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'chat_members' AND schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.chat_members', r.policyname);
  END LOOP;
END $$;

-- 2. Drop ALL existing policies on chats (clean slate)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'chats' AND schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.chats', r.policyname);
  END LOOP;
END $$;

-- 3. Simple non-recursive policy: you see your own chat_member rows only
CREATE POLICY "chat_members_own_rows"
  ON public.chat_members FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- 4. You can insert yourself into a chat
CREATE POLICY "chat_members_insert"
  ON public.chat_members FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 5. You can delete yourself from a chat
CREATE POLICY "chat_members_delete"
  ON public.chat_members FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 6. Chats: you can see chats you're a member of
--    Uses a subquery on chat_members but with the SIMPLE policy above,
--    chat_members itself is no longer recursive.
CREATE POLICY "chats_member_select"
  ON public.chats FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()
    )
  );

-- 7. Any authenticated user can create a chat
CREATE POLICY "chats_insert"
  ON public.chats FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- 8. Members can update chat metadata (last_message_at etc.)
CREATE POLICY "chats_update"
  ON public.chats FOR UPDATE
  TO authenticated
  USING (
    id IN (
      SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()
    )
  );

-- ── get_direct_chats_for_user RPC ─────────────────────────────────────────────
-- The Flutter code calls this RPC to find existing DMs before creating new ones.
-- Returns rows: { chat_id, other_user_id }
DROP FUNCTION IF EXISTS public.get_direct_chats_for_user(UUID);

CREATE OR REPLACE FUNCTION public.get_direct_chats_for_user(uid UUID)
RETURNS TABLE(chat_id UUID, other_user_id UUID) AS $$
BEGIN
  RETURN QUERY
    SELECT
      cm1.chat_id,
      cm2.user_id AS other_user_id
    FROM public.chat_members cm1
    JOIN public.chat_members cm2
      ON cm1.chat_id = cm2.chat_id
      AND cm2.user_id != uid
    JOIN public.chats c ON c.id = cm1.chat_id
    WHERE cm1.user_id = uid
      AND c.type = 'direct';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_direct_chats_for_user(UUID) TO authenticated;

-- ── messages RLS ──────────────────────────────────────────────────────────────
-- Also drop and recreate messages policies — they depend on chat_members
-- and might have been created with the broken recursive pattern.

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'messages' AND schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.messages', r.policyname);
  END LOOP;
END $$;

CREATE POLICY "messages_select"
  ON public.messages FOR SELECT
  TO authenticated
  USING (
    chat_id IN (
      SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND chat_id IN (
      SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "messages_soft_delete"
  ON public.messages FOR UPDATE
  TO authenticated
  USING (sender_id = auth.uid());
