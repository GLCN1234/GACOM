-- ============================================================
-- GACOM Patch 6 — Safe SQL — Run in Supabase SQL Editor
-- ============================================================

-- ── 1. Fix get_user_id_by_email (drop first to allow return type change) ─────
DROP FUNCTION IF EXISTS public.get_user_id_by_email(TEXT);

CREATE FUNCTION public.get_user_id_by_email(email TEXT)
RETURNS TEXT AS $$
DECLARE
  result_id UUID;
BEGIN
  SELECT id INTO result_id FROM auth.users
  WHERE auth.users.email = get_user_id_by_email.email LIMIT 1;
  RETURN result_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_user_id_by_email(TEXT) TO authenticated;

-- ── 2. exco_assignments ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.exco_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exco_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  exco_role TEXT NOT NULL,
  assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(exco_id, exco_role)
);
ALTER TABLE public.exco_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage exco assignments" ON public.exco_assignments;
CREATE POLICY "Admins manage exco assignments" ON public.exco_assignments
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

DROP POLICY IF EXISTS "Exco can view their own assignment" ON public.exco_assignments;
CREATE POLICY "Exco can view their own assignment" ON public.exco_assignments
FOR SELECT TO authenticated USING (exco_id = auth.uid());

-- ── 3. Blog posts RLS ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Exco blog editors can manage posts" ON public.blog_posts;
CREATE POLICY "Exco blog editors can manage posts" ON public.blog_posts
FOR ALL TO authenticated
USING (
  auth.uid() = author_id
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  OR EXISTS (SELECT 1 FROM public.exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'blog_editor')
  OR EXISTS (SELECT 1 FROM public.admin_permissions WHERE admin_id = auth.uid() AND permission = 'manage_blog')
);

DROP POLICY IF EXISTS "Anyone can read published blogs" ON public.blog_posts;
CREATE POLICY "Anyone can read published blogs" ON public.blog_posts
FOR SELECT TO public USING (is_published = true);

-- ── 4. Notifications RLS ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users see own notifications" ON public.notifications;
CREATE POLICY "Users see own notifications" ON public.notifications
FOR SELECT TO authenticated USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications" ON public.notifications
FOR INSERT TO authenticated WITH CHECK (true);

-- ── 5. Admin permissions RLS ──────────────────────────────────────────────────
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins manage permissions" ON public.admin_permissions;
CREATE POLICY "Admins manage permissions" ON public.admin_permissions
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

-- ── 6. FIX CHAT 500 ERROR ─────────────────────────────────────────────────────
-- The nested query on chat_members causes 500 due to RLS blocking the join.
-- Solution: give members full visibility of chats and members they belong to.

DROP POLICY IF EXISTS "Chat members can view chats" ON public.chats;
CREATE POLICY "Chat members can view chats" ON public.chats
FOR SELECT TO authenticated
USING (id IN (SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can create chats" ON public.chats;
CREATE POLICY "Authenticated users can create chats" ON public.chats
FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "Chat members can update chats" ON public.chats;
CREATE POLICY "Chat members can update chats" ON public.chats
FOR UPDATE TO authenticated
USING (id IN (SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Members can see chat members" ON public.chat_members;
CREATE POLICY "Members can see chat members" ON public.chat_members
FOR SELECT TO authenticated
USING (chat_id IN (SELECT chat_id FROM public.chat_members cm2 WHERE cm2.user_id = auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can join chats" ON public.chat_members;
CREATE POLICY "Authenticated users can join chats" ON public.chat_members
FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Chat members see messages" ON public.messages;
CREATE POLICY "Chat members see messages" ON public.messages
FOR SELECT TO authenticated
USING (chat_id IN (SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Chat members send messages" ON public.messages;
CREATE POLICY "Chat members send messages" ON public.messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND chat_id IN (SELECT chat_id FROM public.chat_members WHERE user_id = auth.uid())
);

-- ── 7. Gaming Teams ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.gaming_teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  tag TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  banner_url TEXT,
  community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
  captain_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  game_name TEXT,
  max_members INTEGER DEFAULT 5,
  members_count INTEGER DEFAULT 1,
  is_recruiting BOOLEAN DEFAULT true,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0,
  total_earnings DECIMAL(15,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.team_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID REFERENCES public.gaming_teams(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(team_id, user_id)
);

ALTER TABLE public.gaming_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teams viewable by all" ON public.gaming_teams;
CREATE POLICY "Teams viewable by all" ON public.gaming_teams FOR SELECT USING (true);

DROP POLICY IF EXISTS "Members can create teams" ON public.gaming_teams;
CREATE POLICY "Members can create teams" ON public.gaming_teams
FOR INSERT TO authenticated WITH CHECK (captain_id = auth.uid());

DROP POLICY IF EXISTS "Captain can manage team" ON public.gaming_teams;
CREATE POLICY "Captain can manage team" ON public.gaming_teams
FOR UPDATE TO authenticated USING (captain_id = auth.uid());

DROP POLICY IF EXISTS "Captain can delete team" ON public.gaming_teams;
CREATE POLICY "Captain can delete team" ON public.gaming_teams
FOR DELETE TO authenticated USING (captain_id = auth.uid());

DROP POLICY IF EXISTS "Team members viewable by all" ON public.team_members;
CREATE POLICY "Team members viewable by all" ON public.team_members FOR SELECT USING (true);

DROP POLICY IF EXISTS "Members can join teams" ON public.team_members;
CREATE POLICY "Members can join teams" ON public.team_members
FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Members can leave teams" ON public.team_members;
CREATE POLICY "Members can leave teams" ON public.team_members
FOR DELETE TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Captain can manage team members" ON public.team_members;
CREATE POLICY "Captain can manage team members" ON public.team_members
FOR ALL TO authenticated
USING (team_id IN (SELECT id FROM public.gaming_teams WHERE captain_id = auth.uid()));

-- Team member count triggers
CREATE OR REPLACE FUNCTION update_team_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.gaming_teams SET members_count = members_count + 1 WHERE id = NEW.team_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.gaming_teams SET members_count = GREATEST(members_count - 1, 0) WHERE id = OLD.team_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_team_member_change ON public.team_members;
CREATE TRIGGER on_team_member_change
  AFTER INSERT OR DELETE ON public.team_members
  FOR EACH ROW EXECUTE FUNCTION update_team_member_count();

-- ── 8. Tournament Management System ──────────────────────────────────────────

-- Add tournament columns to competitions
ALTER TABLE public.competitions
  ADD COLUMN IF NOT EXISTS tournament_format TEXT DEFAULT 'single_elimination',
  ADD COLUMN IF NOT EXISTS match_type TEXT DEFAULT 'solo',
  ADD COLUMN IF NOT EXISTS team_size INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS allows_team_registration BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS allows_solo_registration BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS lobby_size INTEGER DEFAULT 2,
  ADD COLUMN IF NOT EXISTS bracket_generated BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ai_moderation_enabled BOOLEAN DEFAULT true;

CREATE TABLE IF NOT EXISTS public.tournament_brackets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
  round_number INTEGER NOT NULL,
  round_name TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tournament_matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
  bracket_id UUID REFERENCES public.tournament_brackets(id) ON DELETE CASCADE,
  match_number INTEGER NOT NULL,
  player1_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  player2_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  team1_id UUID REFERENCES public.gaming_teams(id) ON DELETE SET NULL,
  team2_id UUID REFERENCES public.gaming_teams(id) ON DELETE SET NULL,
  winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  winner_team_id UUID REFERENCES public.gaming_teams(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'scheduled',
  scheduled_at TIMESTAMP WITH TIME ZONE,
  room_id_assigned TEXT,
  room_password_assigned TEXT,
  room_assigned_at TIMESTAMP WITH TIME ZONE,
  match_type TEXT DEFAULT 'solo',
  is_bye BOOLEAN DEFAULT false,
  next_match_id UUID,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.game_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
  room_name TEXT NOT NULL,
  room_code TEXT NOT NULL,
  room_password TEXT,
  max_players INTEGER DEFAULT 2,
  current_match_id UUID REFERENCES public.tournament_matches(id) ON DELETE SET NULL,
  is_available BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.match_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID REFERENCES public.tournament_matches(id) ON DELETE CASCADE,
  submitted_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  claimed_winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  claimed_winner_team_id UUID REFERENCES public.gaming_teams(id) ON DELETE SET NULL,
  score_self INTEGER,
  score_opponent INTEGER,
  evidence_urls TEXT[],
  notes TEXT,
  is_disputed BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(match_id, submitted_by)
);

CREATE TABLE IF NOT EXISTS public.match_disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id UUID REFERENCES public.tournament_matches(id) ON DELETE CASCADE,
  reported_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  evidence_urls TEXT[],
  status TEXT DEFAULT 'open',
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.competition_team_registrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.gaming_teams(id) ON DELETE CASCADE,
  registered_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  payment_status TEXT DEFAULT 'pending',
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(competition_id, team_id)
);

ALTER TABLE public.tournament_brackets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competition_team_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Brackets viewable by all" ON public.tournament_brackets;
CREATE POLICY "Brackets viewable by all" ON public.tournament_brackets FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins manage brackets" ON public.tournament_brackets;
CREATE POLICY "Admins manage brackets" ON public.tournament_brackets FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

DROP POLICY IF EXISTS "Matches viewable by all" ON public.tournament_matches;
CREATE POLICY "Matches viewable by all" ON public.tournament_matches FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins manage matches" ON public.tournament_matches;
CREATE POLICY "Admins manage matches" ON public.tournament_matches FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

DROP POLICY IF EXISTS "Rooms viewable by authenticated" ON public.game_rooms;
CREATE POLICY "Rooms viewable by authenticated" ON public.game_rooms FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Admins manage game rooms" ON public.game_rooms;
CREATE POLICY "Admins manage game rooms" ON public.game_rooms FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

DROP POLICY IF EXISTS "Players submit results" ON public.match_results;
CREATE POLICY "Players submit results" ON public.match_results
FOR INSERT TO authenticated WITH CHECK (submitted_by = auth.uid());
DROP POLICY IF EXISTS "Results viewable by all" ON public.match_results;
CREATE POLICY "Results viewable by all" ON public.match_results FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Admins manage results" ON public.match_results;
CREATE POLICY "Admins manage results" ON public.match_results FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

DROP POLICY IF EXISTS "Players file disputes" ON public.match_disputes;
CREATE POLICY "Players file disputes" ON public.match_disputes
FOR INSERT TO authenticated WITH CHECK (reported_by = auth.uid());
DROP POLICY IF EXISTS "Disputes viewable by all" ON public.match_disputes;
CREATE POLICY "Disputes viewable by all" ON public.match_disputes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Team registrations viewable by all" ON public.competition_team_registrations;
CREATE POLICY "Team registrations viewable by all" ON public.competition_team_registrations FOR SELECT USING (true);
DROP POLICY IF EXISTS "Captains register teams" ON public.competition_team_registrations;
CREATE POLICY "Captains register teams" ON public.competition_team_registrations
FOR INSERT TO authenticated WITH CHECK (registered_by = auth.uid());

-- Realtime
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='tournament_matches') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tournament_matches;
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='match_results') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.match_results;
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='exco_assignments') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.exco_assignments;
  END IF;
END $$;
