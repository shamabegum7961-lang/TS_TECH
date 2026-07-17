
/*
# TS Tech Canopy — Referrals, Loyalty & Admin Schema

## Overview
Three separate feature additions on top of the existing schema.

## New Tables

### profiles
Auto-created on user signup via trigger. Holds display info and admin flag.
- id: references auth.users, primary key
- email, full_name
- is_admin: boolean, defaults false — manually set to true for admin users
- avatar_url: optional

### referral_codes
One code per user. Auto-generated 8-char code.
- id, user_id
- code: unique alphanumeric, 8 chars
- reward_per_referral: amount referrer earns per successful referral (default ₹50)
- referred_reward: amount new user gets off first order (default ₹25)
- uses_count: how many times it was used
- is_active
- created_at

### referral_uses
Records each time a referral code is used (signup + first order).
- id, referral_code_id, referred_user_id
- status: pending (signed up but not ordered yet) | credited (order placed, reward issued)
- order_id: the qualifying order
- referrer_reward: amount credited to referrer
- referred_reward: amount discounted for new user
- created_at

### referral_credits
Wallet of earned referral credits per user. One row per credit event.
- id, user_id, amount, description, is_used
- created_at

### loyalty_memberships
One row per user, updated whenever orders change.
- user_id (primary key)
- tier: bronze | silver | gold | platinum
- total_spend: cumulative total from all non-cancelled orders
- total_orders: count of completed/delivered orders
- points: floor(total_spend / 100)
- next_tier_points: points needed to reach next tier
- tier_since: when they reached current tier
- last_updated_at

## Tier Algorithm
- Bronze  : 0 – 499 points  (0 – ₹49,999 spend)
- Silver  : 500 – 1499 points (₹50,000 – ₹149,999 spend)
- Gold    : 1500 – 4999 points (₹150,000 – ₹499,999 spend)
- Platinum: 5000+ points  (₹500,000+ spend)
1 point = ₹100 spent.

## Security
- profiles: user reads own row, anon+auth can read basic info
- referral_codes: authenticated users can CRUD their own code
- referral_uses: authenticated users can read uses of their own code
- referral_credits: users can only read their own credits
- loyalty_memberships: users can only read their own membership
*/

-- ─── PROFILES ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  avatar_url text,
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_profiles" ON profiles;
CREATE POLICY "public_read_profiles" ON profiles FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "users_update_own_profile" ON profiles;
CREATE POLICY "users_update_own_profile" ON profiles FOR UPDATE
  TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "users_insert_own_profile" ON profiles;
CREATE POLICY "users_insert_own_profile" ON profiles FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── REFERRAL CODES ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  code text UNIQUE NOT NULL,
  reward_per_referral numeric(10,2) NOT NULL DEFAULT 50.00,
  referred_reward numeric(10,2) NOT NULL DEFAULT 25.00,
  uses_count int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS referral_codes_code_idx ON referral_codes(code);

ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_referral_code" ON referral_codes;
CREATE POLICY "select_own_referral_code" ON referral_codes FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "anon_lookup_referral_code" ON referral_codes;
CREATE POLICY "anon_lookup_referral_code" ON referral_codes FOR SELECT
  TO anon USING (is_active = true);

DROP POLICY IF EXISTS "insert_own_referral_code" ON referral_codes;
CREATE POLICY "insert_own_referral_code" ON referral_codes FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_referral_code" ON referral_codes;
CREATE POLICY "update_own_referral_code" ON referral_codes FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── REFERRAL USES ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referral_uses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_code_id uuid NOT NULL REFERENCES referral_codes(id) ON DELETE CASCADE,
  referred_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','credited')),
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  referrer_reward numeric(10,2),
  referred_discount numeric(10,2),
  created_at timestamptz DEFAULT now(),
  UNIQUE (referred_user_id)
);

ALTER TABLE referral_uses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referrer_reads_uses" ON referral_uses;
CREATE POLICY "referrer_reads_uses" ON referral_uses FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM referral_codes
      WHERE referral_codes.id = referral_uses.referral_code_id
        AND referral_codes.user_id = auth.uid()
    )
    OR referred_user_id = auth.uid()
  );

DROP POLICY IF EXISTS "insert_referral_use" ON referral_uses;
CREATE POLICY "insert_referral_use" ON referral_uses FOR INSERT
  TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "update_referral_use" ON referral_uses;
CREATE POLICY "update_referral_use" ON referral_uses FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM referral_codes
      WHERE referral_codes.id = referral_uses.referral_code_id
        AND referral_codes.user_id = auth.uid()
    )
  );

-- ─── REFERRAL CREDITS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referral_credits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric(10,2) NOT NULL,
  description text NOT NULL DEFAULT 'Referral reward',
  is_used boolean NOT NULL DEFAULT false,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS referral_credits_user_idx ON referral_credits(user_id);

ALTER TABLE referral_credits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_credits" ON referral_credits;
CREATE POLICY "select_own_credits" ON referral_credits FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_credits" ON referral_credits;
CREATE POLICY "insert_own_credits" ON referral_credits FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_credits" ON referral_credits;
CREATE POLICY "update_own_credits" ON referral_credits FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── LOYALTY MEMBERSHIPS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS loyalty_memberships (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier text NOT NULL DEFAULT 'bronze' CHECK (tier IN ('bronze','silver','gold','platinum')),
  total_spend numeric(10,2) NOT NULL DEFAULT 0,
  total_orders int NOT NULL DEFAULT 0,
  points int NOT NULL DEFAULT 0,
  next_tier_points int NOT NULL DEFAULT 500,
  tier_since timestamptz DEFAULT now(),
  last_updated_at timestamptz DEFAULT now()
);

ALTER TABLE loyalty_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_loyalty" ON loyalty_memberships;
CREATE POLICY "select_own_loyalty" ON loyalty_memberships FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "upsert_own_loyalty" ON loyalty_memberships;
CREATE POLICY "upsert_own_loyalty" ON loyalty_memberships FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_loyalty" ON loyalty_memberships;
CREATE POLICY "update_own_loyalty" ON loyalty_memberships FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── LOYALTY TIER FUNCTION ───────────────────────────────────────────────────
-- Computes tier from points (call this whenever an order is placed)
CREATE OR REPLACE FUNCTION public.compute_tier(points_in int)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN points_in >= 5000 THEN 'platinum'
    WHEN points_in >= 1500 THEN 'gold'
    WHEN points_in >= 500  THEN 'silver'
    ELSE 'bronze'
  END;
$$;

CREATE OR REPLACE FUNCTION public.next_tier_points_needed(points_in int)
RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN points_in >= 5000 THEN 0
    WHEN points_in >= 1500 THEN 5000 - points_in
    WHEN points_in >= 500  THEN 1500 - points_in
    ELSE 500 - points_in
  END;
$$;

-- ─── UPDATE LOYALTY ON ORDER ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.refresh_loyalty_for_user(uid uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_spend    numeric;
  v_orders   int;
  v_points   int;
  v_tier     text;
  v_next     int;
  v_old_tier text;
BEGIN
  SELECT
    COALESCE(SUM(total), 0),
    COUNT(*)
  INTO v_spend, v_orders
  FROM orders
  WHERE user_id = uid
    AND status NOT IN ('cancelled', 'pending');

  v_points := floor(v_spend / 100)::int;
  v_tier   := public.compute_tier(v_points);
  v_next   := public.next_tier_points_needed(v_points);

  -- Get old tier if exists
  SELECT tier INTO v_old_tier FROM loyalty_memberships WHERE user_id = uid;

  INSERT INTO loyalty_memberships (user_id, tier, total_spend, total_orders, points, next_tier_points, tier_since, last_updated_at)
  VALUES (
    uid, v_tier, v_spend, v_orders, v_points, v_next,
    CASE WHEN v_old_tier IS DISTINCT FROM v_tier THEN now() ELSE COALESCE((SELECT tier_since FROM loyalty_memberships WHERE user_id = uid), now()) END,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    tier           = EXCLUDED.tier,
    total_spend    = EXCLUDED.total_spend,
    total_orders   = EXCLUDED.total_orders,
    points         = EXCLUDED.points,
    next_tier_points = EXCLUDED.next_tier_points,
    tier_since     = EXCLUDED.tier_since,
    last_updated_at = now();
END;
$$;

-- Auto-update loyalty when an order status changes
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Only recalculate when an order moves to confirmed/delivered (not pending/cancelled)
  IF NEW.status IN ('confirmed', 'delivered') THEN
    PERFORM public.refresh_loyalty_for_user(NEW.user_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_status_change ON orders;
CREATE TRIGGER on_order_status_change
  AFTER INSERT OR UPDATE OF status ON orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_order_status_change();

-- ─── ADMIN READ POLICIES ─────────────────────────────────────────────────────
-- Admins can read all contact submissions (added to the existing table)
DROP POLICY IF EXISTS "admin_read_contacts" ON contact_submissions;
CREATE POLICY "admin_read_contacts" ON contact_submissions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  );

-- Admins can manage all products
DROP POLICY IF EXISTS "admin_all_products" ON products;
CREATE POLICY "admin_all_products" ON products FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  );

-- Admins can read all orders
DROP POLICY IF EXISTS "admin_read_all_orders" ON orders;
CREATE POLICY "admin_read_all_orders" ON orders FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  );
