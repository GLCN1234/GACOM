-- ============================================================
-- GACOM Patch 8 — DEFINITIVE Chat RLS Recursion Fix
-- ============================================================
-- Run this in Supabase SQL Editor.
-- This completely wipes and rebuilds all chat/message policies
-- using a SECURITY DEFINER function to prevent infinite recursion.
--
-- ROOT CAUSE:
--   The policy on chat_members used a subquery that selected FROM
--   chat_members — querying the same table the policy guards causes
--   Postgres to call the policy again → infinite loop → code 42P17.
--
-- FIX:
--   A SECURITY DEFINER function bypasses RLS when it runs, breaking
--   the recursive cycle. All policies reference this function only.
-- ============================================================

-- ── STEP 1: Drop EVERY policy on chats, chat_members, messages ───────────────
-- (Drop by ALL known names from every patch to guarantee a clean slate)

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('chats', 'chat_members', 'messages')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
    RAISE NOTICE 'Dropped policy % on %', pol.policyname, pol.tablename;
  END LOOP;
END
$$;

-- ── STEP 2: Drop and recreate the SECURITY DEFINER helper ────────────────────

DROP FUNCTION IF EXISTS public.user_chat_ids(UUID);

CREATE FUNCTION public.user_chat_ids(uid UUID)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT chat_id FROM public.chat_members WHERE user_id = uid;
$$;

GRANT EXECUTE ON FUNCTION public.user_chat_ids(UUID) TO authenticated, anon;

-- ── STEP 3: Recreate clean policies on chats ─────────────────────────────────

CREATE POLICY "chats_select" ON public.chats
  FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_chat_ids(auth.uid())));

CREATE POLICY "chats_insert" ON public.chats
  FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "chats_update" ON public.chats
  FOR UPDATE TO authenticated
  USING (id IN (SELECT public.user_chat_ids(auth.uid())));

-- ── STEP 4: Recreate clean policies on chat_members ──────────────────────────
-- NOTE: chat_members policies MUST use user_chat_ids(), NOT a direct subquery
-- on chat_members itself — that is what causes the recursion.

CREATE POLICY "chat_members_select" ON public.chat_members
  FOR SELECT TO authenticated
  USING (chat_id IN (SELECT public.user_chat_ids(auth.uid())));

CREATE POLICY "chat_members_insert" ON public.chat_members
  FOR INSERT TO authenticated
  WITH CHECK (true);  -- allow any authenticated user to be added to a chat

CREATE POLICY "chat_members_delete" ON public.chat_members
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ── STEP 5: Recreate clean policies on messages ──────────────────────────────

CREATE POLICY "messages_select" ON public.messages
  FOR SELECT TO authenticated
  USING (chat_id IN (SELECT public.user_chat_ids(auth.uid())));

CREATE POLICY "messages_insert" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND chat_id IN (SELECT public.user_chat_ids(auth.uid()))
  );

-- ── STEP 6: Recreate the get_direct_chats_for_user RPC ───────────────────────
-- Used by the Flutter chat screen to find existing DMs without recursion.

DROP FUNCTION IF EXISTS public.get_direct_chats_for_user(UUID);

CREATE FUNCTION public.get_direct_chats_for_user(uid UUID)
RETURNS TABLE(chat_id UUID, other_user_id UUID)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT cm1.chat_id, cm2.user_id AS other_user_id
  FROM public.chat_members cm1
  JOIN public.chat_members cm2
    ON cm1.chat_id = cm2.chat_id AND cm2.user_id != uid
  JOIN public.chats c
    ON c.id = cm1.chat_id AND c.type = 'direct'
  WHERE cm1.user_id = uid;
$$;

GRANT EXECUTE ON FUNCTION public.get_direct_chats_for_user(UUID) TO authenticated;

-- ── STEP 7: Verify (optional — check no recursive policies remain) ────────────
-- SELECT policyname, tablename, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('chats', 'chat_members', 'messages')
-- ORDER BY tablename, policyname;
