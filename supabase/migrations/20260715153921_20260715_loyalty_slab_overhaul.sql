/*
# Loyalty System Overhaul — Slab-Based Points + Redemption

## Summary
Replaces the tier-based loyalty system (bronze/silver/gold/platinum) with a simple
slab-based points system. Points are earned per order based on order value slabs.
Points can be redeemed at checkout (100 points = ₹50). Adds columns to the orders
table to track redeemed points and loyalty discount.

## New Columns on `orders`
1. `points_redeemed` (integer, default 0) — number of loyalty points used on this order
2. `loyalty_discount` (numeric, default 0) — rupee discount applied from redeemed points

## Function Changes
1. `refresh_loyalty_for_user(uid)` — rewritten to compute points using the new slab system.
   Points are awarded per confirmed/delivered order based on the order's subtotal:
     ₹300–₹799     → 40 points
     ₹800–₹1,499   → 60 points
     ₹1,500–₹2,400 → 100 points
     ₹2,401–₹3,500 → 200 points
   Points from redeemed orders are subtracted (points_redeemed column on orders).
   The tier column is kept for backward compatibility but always set to 'member'.
   next_tier_points is set to 0 since tiers no longer apply.

2. `compute_tier(points_in)` — simplified to always return 'member'.

3. `next_tier_points_needed(points_in)` — simplified to always return 0.

## Security
No new tables. No RLS changes. Existing policies on loyalty_memberships remain.

## Important Notes
- The `tier` column on loyalty_memberships is kept (NOT NULL constraint) but now always
  holds 'member'. This avoids destructive schema changes.
- Points are recalculated from scratch each time refresh_loyalty_for_user is called,
  ensuring consistency even if data was modified directly.
*/

-- Add columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'points_redeemed') THEN
    ALTER TABLE orders ADD COLUMN points_redeemed integer NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'loyalty_discount') THEN
    ALTER TABLE orders ADD COLUMN loyalty_discount numeric NOT NULL DEFAULT 0;
  END IF;
END $$;

-- Rewrite compute_tier to always return 'member'
CREATE OR REPLACE FUNCTION public.compute_tier(points_in integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT 'member'::text;
$function$;

-- Rewrite next_tier_points_needed to always return 0
CREATE OR REPLACE FUNCTION public.next_tier_points_needed(points_in integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT 0;
$function$;

-- Rewrite refresh_loyalty_for_user with slab-based points
CREATE OR REPLACE FUNCTION public.refresh_loyalty_for_user(uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_total_spend numeric := 0;
  v_total_orders int := 0;
  v_earned_points int := 0;
  v_redeemed_points int := 0;
  v_net_points int := 0;
  o_record RECORD;
BEGIN
  -- Sum up from all non-cancelled orders
  FOR o_record IN
    SELECT subtotal, status, points_redeemed
    FROM orders
    WHERE user_id = uid AND status IN ('confirmed', 'shipped', 'delivered')
  LOOP
    v_total_spend := v_total_spend + o_record.subtotal;
    v_total_orders := v_total_orders + 1;

    -- Award points based on slab
    IF o_record.subtotal >= 300 AND o_record.subtotal <= 799 THEN
      v_earned_points := v_earned_points + 40;
    ELSIF o_record.subtotal >= 800 AND o_record.subtotal <= 1499 THEN
      v_earned_points := v_earned_points + 60;
    ELSIF o_record.subtotal >= 1500 AND o_record.subtotal <= 2400 THEN
      v_earned_points := v_earned_points + 100;
    ELSIF o_record.subtotal >= 2401 AND o_record.subtotal <= 3500 THEN
      v_earned_points := v_earned_points + 200;
    END IF;

    -- Subtract redeemed points
    v_redeemed_points := v_redeemed_points + COALESCE(o_record.points_redeemed, 0);
  END LOOP;

  v_net_points := v_earned_points - v_redeemed_points;
  IF v_net_points < 0 THEN v_net_points := 0; END IF;

  -- Upsert into loyalty_memberships
  INSERT INTO loyalty_memberships (user_id, tier, total_spend, total_orders, points, next_tier_points, tier_since, last_updated_at)
  VALUES (uid, 'member', v_total_spend, v_total_orders, v_net_points, 0, now(), now())
  ON CONFLICT (user_id) DO UPDATE
  SET tier = 'member',
      total_spend = v_total_spend,
      total_orders = v_total_orders,
      points = v_net_points,
      next_tier_points = 0,
      last_updated_at = now();
END;
$function$;

-- Ensure the unique constraint on user_id exists for the ON CONFLICT
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'loyalty_memberships_user_id_key'
  ) THEN
    ALTER TABLE loyalty_memberships ADD CONSTRAINT loyalty_memberships_user_id_key UNIQUE (user_id);
  END IF;
END $$;
