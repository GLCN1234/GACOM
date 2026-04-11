-- ============================================================
-- GACOM Patch 7 — CRITICAL FIX: Chat Infinite Recursion
-- Run in Supabase SQL Editor
-- ============================================================

-- ── ROOT CAUSE ────────────────────────────────────────────────────────────────
-- The policy "Members can see chat members" uses a subquery on chat_members
-- itself, which triggers itself → infinite recursion.
-- FIX: Use a security definer function to break the cycle.

-- Step 1: Drop ALL existing chat/message policies (clean slate)
DROP POLICY IF EXISTS "Chat members can view chats"          ON public.chats;
DROP POLICY IF EXISTS "Authenticated users can create chats" ON public.chats;
DROP POLICY IF EXISTS "Chat members can update chats"        ON public.chats;
DROP POLICY IF EXISTS "Members can see chat members"         ON public.chat_members;
DROP POLICY IF EXISTS "Authenticated users can join chats"   ON public.chat_members;
DROP POLICY IF EXISTS "Chat members see messages"            ON public.messages;
DROP POLICY IF EXISTS "Chat members send messages"           ON public.messages;

-- Also drop any older policies that might exist with different names
DROP POLICY IF EXISTS "Public profiles viewable by all"      ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile"         ON public.profiles;

-- Step 2: Create a SECURITY DEFINER helper function
-- This bypasses RLS when checking membership, breaking the recursion loop.
CREATE OR REPLACE FUNCTION public.user_chat_ids(uid UUID)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT chat_id FROM chat_members WHERE user_id = uid;
$$;

GRANT EXECUTE ON FUNCTION public.user_chat_ids(UUID) TO authenticated;

-- Step 3: Recreate all policies using the helper function

-- CHATS
CREATE POLICY "chats_select" ON public.chats
  FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_chat_ids(auth.uid())));

CREATE POLICY "chats_insert" ON public.chats
  FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "chats_update" ON public.chats
  FOR UPDATE TO authenticated
  USING (id IN (SELECT public.user_chat_ids(auth.uid())));

-- CHAT_MEMBERS
CREATE POLICY "chat_members_select" ON public.chat_members
  FOR SELECT TO authenticated
  USING (chat_id IN (SELECT public.user_chat_ids(auth.uid())));

CREATE POLICY "chat_members_insert" ON public.chat_members
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "chat_members_delete" ON public.chat_members
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- MESSAGES
CREATE POLICY "messages_select" ON public.messages
  FOR SELECT TO authenticated
  USING (chat_id IN (SELECT public.user_chat_ids(auth.uid())));

CREATE POLICY "messages_insert" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND chat_id IN (SELECT public.user_chat_ids(auth.uid()))
  );

-- Step 4: Restore profiles RLS (drop + recreate cleanly)
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id);

-- Step 5: Fix the "existing DM check" query that also causes 500
-- The Flutter code does:
--   from('chats').select('id, members:chat_members(user_id)').eq('type','direct')
-- This nested select also triggers recursion. Create a safe function for it.

CREATE OR REPLACE FUNCTION public.get_direct_chats_for_user(uid UUID)
RETURNS TABLE(chat_id UUID, other_user_id UUID)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cm1.chat_id, cm2.user_id AS other_user_id
  FROM chat_members cm1
  JOIN chat_members cm2 ON cm1.chat_id = cm2.chat_id AND cm2.user_id != uid
  JOIN chats c ON c.id = cm1.chat_id AND c.type = 'direct'
  WHERE cm1.user_id = uid;
$$;

GRANT EXECUTE ON FUNCTION public.get_direct_chats_for_user(UUID) TO authenticated;
