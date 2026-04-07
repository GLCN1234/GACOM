-- ============================================================
-- GACOM PATCH v2 — Additional Schema
-- Run this in Supabase SQL editor AFTER the original schema
-- ============================================================

-- ── Exco Assignments ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS exco_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exco_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  exco_role TEXT NOT NULL, -- community_manager | inventory_manager | finance_team | customer_agent
  assigned_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(exco_id, exco_role)
);

-- ── Support Tickets ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  issue TEXT NOT NULL,
  status TEXT DEFAULT 'open', -- open | in_progress | resolved | closed
  assigned_agent_id UUID REFERENCES profiles(id),
  ai_transcript TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── Support Messages ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id UUID REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_agent BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── Withdrawal Requests ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount DECIMAL(15,2) NOT NULL,
  account_number TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  status TEXT DEFAULT 'pending', -- pending | approved | rejected
  processed_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── Bank Accounts ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bank_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, account_number)
);

-- ── Ad Campaigns ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ad_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  advertiser_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  destination_url TEXT,
  ad_type TEXT DEFAULT 'banner', -- banner | interstitial | feed
  target_audience TEXT DEFAULT 'all_gamers',
  daily_budget DECIMAL(10,2) DEFAULT 0,
  status TEXT DEFAULT 'pending_review', -- pending_review | active | paused | ended | rejected
  impressions INTEGER DEFAULT 0,
  clicks INTEGER DEFAULT 0,
  spend DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── Bug Reports ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bug_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  app_version TEXT,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── Extend profiles for privacy ───────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country TEXT;

-- ── RPC: increment posts_count ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION increment_posts_count(user_id UUID)
RETURNS void AS $$
  UPDATE profiles SET posts_count = COALESCE(posts_count, 0) + 1
  WHERE id = user_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── RPC: get user id by email ─────────────────────────────────────────────────
-- Used by admin dashboard to assign exco roles by email
CREATE OR REPLACE FUNCTION get_user_id_by_email(email TEXT)
RETURNS UUID AS $$
  SELECT id FROM auth.users WHERE auth.users.email = get_user_id_by_email.email LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── RLS Policies ─────────────────────────────────────────────────────────────

-- Support tickets: users see own, agents see all
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_tickets" ON support_tickets
  FOR ALL USING (
    auth.uid() = user_id OR
    auth.uid() = assigned_agent_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')) OR
    EXISTS (SELECT 1 FROM exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'customer_agent')
  );

-- Support messages
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ticket_participants_messages" ON support_messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM support_tickets st
      WHERE st.id = ticket_id AND (
        auth.uid() = st.user_id OR
        auth.uid() = st.assigned_agent_id OR
        EXISTS (SELECT 1 FROM exco_assignments WHERE exco_id = auth.uid())
      )
    )
  );

-- Withdrawal requests: user sees own, finance team sees all
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_withdrawals" ON withdrawal_requests
  FOR ALL USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')) OR
    EXISTS (SELECT 1 FROM exco_assignments WHERE exco_id = auth.uid() AND exco_role = 'finance_team')
  );

-- Exco assignments: admins manage, exco members see own
ALTER TABLE exco_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admins_manage_exco" ON exco_assignments
  FOR ALL USING (
    auth.uid() = exco_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- Ad campaigns: advertiser sees own, admins see all
ALTER TABLE ad_campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "advertiser_campaigns" ON ad_campaigns
  FOR ALL USING (
    auth.uid() = advertiser_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- Bank accounts: private
ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_bank_accounts" ON bank_accounts
  FOR ALL USING (auth.uid() = user_id);

-- Bug reports
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_bug_reports" ON bug_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "admin_view_bugs" ON bug_reports
  FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- ── Indexes ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_agent ON support_tickets(assigned_agent_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_messages_ticket ON support_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_exco_assignments_role ON exco_assignments(exco_role);
CREATE INDEX IF NOT EXISTS idx_withdrawal_status ON withdrawal_requests(status);
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_advertiser ON ad_campaigns(advertiser_id);
CREATE INDEX IF NOT EXISTS idx_profiles_location ON profiles(location);
