-- Ensure unique review per user per product
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reviews_user_product_unique'
  ) THEN
    ALTER TABLE reviews ADD CONSTRAINT reviews_user_product_unique UNIQUE (product_id, user_id);
  END IF;
END $$;

-- RLS for reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'select_all_reviews' AND tablename = 'reviews') THEN
    CREATE POLICY "select_all_reviews" ON reviews FOR SELECT TO anon, authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'insert_own_review' AND tablename = 'reviews') THEN
    CREATE POLICY "insert_own_review" ON reviews FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'update_own_review' AND tablename = 'reviews') THEN
    CREATE POLICY "update_own_review" ON reviews FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'delete_own_review' AND tablename = 'reviews') THEN
    CREATE POLICY "delete_own_review" ON reviews FOR DELETE TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;
