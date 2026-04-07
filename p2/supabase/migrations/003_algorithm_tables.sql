-- ============================================================
-- GACOM Algorithm Support — Run in Supabase SQL Editor
-- ============================================================

-- Post saves table (used in algorithm scoring)
CREATE TABLE IF NOT EXISTS public.post_saves (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.post_saves ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own saves" ON public.post_saves FOR ALL USING (auth.uid() = user_id);

-- Post views tracking (feeds algorithm signals)
CREATE TABLE IF NOT EXISTS public.post_views (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  watch_time_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.post_views ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own views" ON public.post_views FOR ALL USING (auth.uid() = user_id);

-- Add is_available column to products if it doesn't exist
-- (the store screen queries this)
DO $$ BEGIN
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS seller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
  ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category TEXT;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- RLS for products — sellers can manage own listings
CREATE POLICY IF NOT EXISTS "Anyone can view available products" ON public.products
  FOR SELECT USING (is_available = true OR seller_id = auth.uid());
CREATE POLICY IF NOT EXISTS "Users can create listings" ON public.products
  FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY IF NOT EXISTS "Sellers can update own listings" ON public.products
  FOR UPDATE USING (auth.uid() = seller_id);

-- Add post_saves column trigger
CREATE OR REPLACE FUNCTION update_post_save_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET shares_count = COALESCE(shares_count, 0) + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET shares_count = GREATEST(COALESCE(shares_count, 0) - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER IF NOT EXISTS on_post_save_change
  AFTER INSERT OR DELETE ON public.post_saves
  FOR EACH ROW EXECUTE FUNCTION update_post_save_count();

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.post_saves;
ALTER PUBLICATION supabase_realtime ADD TABLE public.post_views;
