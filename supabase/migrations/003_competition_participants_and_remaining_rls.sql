-- ============================================================
-- GACOM FIX: competition_participants 403 + remaining policies
-- Paste into Supabase SQL Editor and RUN
-- ============================================================

-- ── competition_participants ──────────────────────────────────────────────────
-- Root cause of POST competition_participants → 403 Forbidden

DO $$ BEGIN
  DROP POLICY IF EXISTS "gacom_comp_participants_select" ON competition_participants;
  DROP POLICY IF EXISTS "gacom_comp_participants_insert" ON competition_participants;
  DROP POLICY IF EXISTS "gacom_comp_participants_delete" ON competition_participants;
  DROP POLICY IF EXISTS "Anyone can view participants" ON competition_participants;
  DROP POLICY IF EXISTS "Users can join competitions" ON competition_participants;
  DROP POLICY IF EXISTS "Users can leave competitions" ON competition_participants;
END $$;

CREATE POLICY "gacom_comp_participants_select"
  ON competition_participants FOR SELECT
  USING (true);

CREATE POLICY "gacom_comp_participants_insert"
  ON competition_participants FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gacom_comp_participants_delete"
  ON competition_participants FOR DELETE
  USING (auth.uid() = user_id);


-- ── competition_results ───────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "gacom_comp_results_select" ON competition_results;
  DROP POLICY IF EXISTS "gacom_comp_results_admin" ON competition_results;
END $$;

ALTER TABLE competition_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gacom_comp_results_select"
  ON competition_results FOR SELECT USING (true);

CREATE POLICY "gacom_comp_results_admin"
  ON competition_results FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin','super_admin')
    )
  );


-- ── wallet_transactions: allow INSERT (competition entry fee deduction) ────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users see own transactions" ON wallet_transactions;
  DROP POLICY IF EXISTS "gacom_wallet_select" ON wallet_transactions;
  DROP POLICY IF EXISTS "gacom_wallet_insert" ON wallet_transactions;
  DROP POLICY IF EXISTS "gacom_wallet_admin" ON wallet_transactions;
END $$;

CREATE POLICY "gacom_wallet_select"
  ON wallet_transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "gacom_wallet_insert"
  ON wallet_transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gacom_wallet_admin"
  ON wallet_transactions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin','super_admin')
    )
  );


-- ── profiles: allow UPDATE of wallet_balance during competition join ──────────
-- The join flow updates wallet_balance on profiles. Ensure this is allowed.
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
  DROP POLICY IF EXISTS "gacom_profiles_update" ON profiles;
END $$;

CREATE POLICY "gacom_profiles_update"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);


-- ── post_likes / post_saves: often missing ───────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "gacom_post_likes_select" ON post_likes;
  DROP POLICY IF EXISTS "gacom_post_likes_insert" ON post_likes;
  DROP POLICY IF EXISTS "gacom_post_likes_delete" ON post_likes;
END $$;

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gacom_post_likes_select"
  ON post_likes FOR SELECT USING (true);

CREATE POLICY "gacom_post_likes_insert"
  ON post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gacom_post_likes_delete"
  ON post_likes FOR DELETE
  USING (auth.uid() = user_id);

DO $$ BEGIN
  DROP POLICY IF EXISTS "gacom_post_saves_select" ON post_saves;
  DROP POLICY IF EXISTS "gacom_post_saves_insert" ON post_saves;
  DROP POLICY IF EXISTS "gacom_post_saves_delete" ON post_saves;
END $$;

ALTER TABLE post_saves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gacom_post_saves_select"
  ON post_saves FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "gacom_post_saves_insert"
  ON post_saves FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gacom_post_saves_delete"
  ON post_saves FOR DELETE
  USING (auth.uid() = user_id);


-- ── post_comments ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "gacom_comments_select" ON post_comments;
  DROP POLICY IF EXISTS "gacom_comments_insert" ON post_comments;
  DROP POLICY IF EXISTS "gacom_comments_delete" ON post_comments;
END $$;

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gacom_comments_select"
  ON post_comments FOR SELECT USING (NOT is_deleted);

CREATE POLICY "gacom_comments_insert"
  ON post_comments FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "gacom_comments_delete"
  ON post_comments FOR DELETE
  USING (auth.uid() = author_id);


-- ── follows ───────────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Follows viewable by all" ON follows;
  DROP POLICY IF EXISTS "Users can follow" ON follows;
  DROP POLICY IF EXISTS "Users can unfollow" ON follows;
  DROP POLICY IF EXISTS "gacom_follows_select" ON follows;
  DROP POLICY IF EXISTS "gacom_follows_insert" ON follows;
  DROP POLICY IF EXISTS "gacom_follows_delete" ON follows;
END $$;

CREATE POLICY "gacom_follows_select"
  ON follows FOR SELECT USING (true);

CREATE POLICY "gacom_follows_insert"
  ON follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "gacom_follows_delete"
  ON follows FOR DELETE
  USING (auth.uid() = follower_id);


-- ── notifications ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users see own notifications" ON notifications;
  DROP POLICY IF EXISTS "Users can mark notifications read" ON notifications;
  DROP POLICY IF EXISTS "gacom_notifs_select" ON notifications;
  DROP POLICY IF EXISTS "gacom_notifs_insert" ON notifications;
  DROP POLICY IF EXISTS "gacom_notifs_update" ON notifications;
END $$;

CREATE POLICY "gacom_notifs_select"
  ON notifications FOR SELECT
  USING (auth.uid() = recipient_id);

CREATE POLICY "gacom_notifs_insert"
  ON notifications FOR INSERT
  WITH CHECK (true);  -- system inserts notifications for any user

CREATE POLICY "gacom_notifs_update"
  ON notifications FOR UPDATE
  USING (auth.uid() = recipient_id);


-- ── chats / chat_members ──────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "gacom_chats_select" ON chats;
  DROP POLICY IF EXISTS "gacom_chats_insert" ON chats;
  DROP POLICY IF EXISTS "gacom_chat_members_select" ON chat_members;
  DROP POLICY IF EXISTS "gacom_chat_members_insert" ON chat_members;
END $$;

ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gacom_chats_select"
  ON chats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM chat_members
      WHERE chat_id = chats.id AND user_id = auth.uid()
    )
  );

CREATE POLICY "gacom_chats_insert"
  ON chats FOR INSERT
  WITH CHECK (true);

CREATE POLICY "gacom_chat_members_select"
  ON chat_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM chat_members cm2
      WHERE cm2.chat_id = chat_members.chat_id AND cm2.user_id = auth.uid()
    )
  );

CREATE POLICY "gacom_chat_members_insert"
  ON chat_members FOR INSERT
  WITH CHECK (true);


-- ── verification_requests ─────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users see own verification" ON verification_requests;
  DROP POLICY IF EXISTS "Users create verification" ON verification_requests;
  DROP POLICY IF EXISTS "Admins manage verification" ON verification_requests;
  DROP POLICY IF EXISTS "gacom_verif_select" ON verification_requests;
  DROP POLICY IF EXISTS "gacom_verif_insert" ON verification_requests;
  DROP POLICY IF EXISTS "gacom_verif_admin" ON verification_requests;
END $$;

CREATE POLICY "gacom_verif_select"
  ON verification_requests FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin','super_admin')
    )
  );

CREATE POLICY "gacom_verif_insert"
  ON verification_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gacom_verif_admin"
  ON verification_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin','super_admin')
    )
  );


-- ── orders / cart ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users see own orders" ON orders;
  DROP POLICY IF EXISTS "Users create own orders" ON orders;
  DROP POLICY IF EXISTS "Users manage own cart" ON cart_items;
  DROP POLICY IF EXISTS "gacom_orders_select" ON orders;
  DROP POLICY IF EXISTS "gacom_orders_insert" ON orders;
  DROP POLICY IF EXISTS "gacom_cart" ON cart_items;
END $$;

CREATE POLICY "gacom_orders_select"
  ON orders FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "gacom_orders_insert"
  ON orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gacom_cart"
  ON cart_items FOR ALL USING (auth.uid() = user_id);


-- ── blog_posts ────────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Published blogs viewable by all" ON blog_posts;
  DROP POLICY IF EXISTS "Admins manage blog" ON blog_posts;
  DROP POLICY IF EXISTS "gacom_blog_select" ON blog_posts;
  DROP POLICY IF EXISTS "gacom_blog_admin" ON blog_posts;
END $$;

CREATE POLICY "gacom_blog_select"
  ON blog_posts FOR SELECT USING (is_published = true);

CREATE POLICY "gacom_blog_admin"
  ON blog_posts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin','super_admin')
    )
  );


-- Done! All policies now cover every table that the app touches.
