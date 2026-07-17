
/*
# TS Tech Canopy — Full E-Commerce Schema

## Overview
Complete e-commerce schema for TS Tech Canopy, a tech accessories reselling business.

## New Tables

### categories
Stores product categories (Mobile Covers, Chargers, Cables, etc.)
- id: uuid primary key
- name: display name
- slug: URL-friendly identifier
- description: category description
- icon: lucide icon name
- image_url: category hero image
- display_order: for sorting on the frontend

### products
Core product catalog
- id, name, slug, description
- price (numeric), compare_price (for showing discounts)
- images: jsonb array of image URLs
- category_id: FK to categories
- brand, model, color, stock_quantity
- is_featured: show on homepage
- is_active: soft-delete / hide
- tags: text array for search
- warranty_info, specifications (jsonb)
- created_at, updated_at

### reviews
Product reviews tied to auth users
- id, product_id, user_id
- rating (1–5), title, body
- is_verified_purchase, created_at

### cart_items
Per-user shopping cart (ephemeral until checkout)
- id, user_id (FK auth.users), product_id, quantity, created_at

### addresses
Saved delivery addresses per user
- id, user_id, label (Home/Work/Other)
- full_name, phone, line1, line2, city, state, pincode
- is_default

### orders
Order header
- id, order_number (human-readable), user_id
- status: pending | confirmed | shipped | delivered | cancelled
- subtotal, shipping_fee, total
- shipping_address_id (snapshot)
- payment_method, payment_status
- notes, created_at, updated_at

### order_items
Line items for each order
- id, order_id, product_id, product_name (snapshot), product_image (snapshot)
- quantity, unit_price

### contact_submissions
Records from the contact form (no auth required)
- id, name, email, phone, subject, message, created_at

## Security
- RLS enabled on all tables.
- Products, categories: public read (anon + authenticated).
- Cart, addresses, orders, reviews: authenticated users see only their own rows.
- Contact submissions: anon + authenticated can insert; nobody can select (server-side only).
*/

-- ─────────────────────────────────────────
-- CATEGORIES
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  description text,
  icon text,
  image_url text,
  display_order int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_categories" ON categories;
CREATE POLICY "public_read_categories" ON categories FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "admin_all_categories" ON categories;
CREATE POLICY "admin_all_categories" ON categories FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────
-- PRODUCTS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE NOT NULL,
  description text,
  price numeric(10,2) NOT NULL,
  compare_price numeric(10,2),
  images jsonb NOT NULL DEFAULT '[]',
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  brand text,
  model text,
  color text,
  stock_quantity int NOT NULL DEFAULT 0,
  is_featured boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  tags text[],
  warranty_info text,
  specifications jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS products_category_idx ON products(category_id);
CREATE INDEX IF NOT EXISTS products_featured_idx ON products(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS products_active_idx ON products(is_active) WHERE is_active = true;

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_products" ON products;
CREATE POLICY "public_read_products" ON products FOR SELECT
  TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS "admin_all_products" ON products;
CREATE POLICY "admin_all_products" ON products FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────
-- REVIEWS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title text,
  body text,
  is_verified_purchase boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reviews_product_idx ON reviews(product_id);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_reviews" ON reviews;
CREATE POLICY "public_read_reviews" ON reviews FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "auth_insert_reviews" ON reviews;
CREATE POLICY "auth_insert_reviews" ON reviews FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "auth_update_own_reviews" ON reviews;
CREATE POLICY "auth_update_own_reviews" ON reviews FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "auth_delete_own_reviews" ON reviews;
CREATE POLICY "auth_delete_own_reviews" ON reviews FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- CART ITEMS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity int NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, product_id)
);

ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_cart" ON cart_items;
CREATE POLICY "select_own_cart" ON cart_items FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_cart" ON cart_items;
CREATE POLICY "insert_own_cart" ON cart_items FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_cart" ON cart_items;
CREATE POLICY "update_own_cart" ON cart_items FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_cart" ON cart_items;
CREATE POLICY "delete_own_cart" ON cart_items FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- ADDRESSES
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  label text NOT NULL DEFAULT 'Home',
  full_name text NOT NULL,
  phone text NOT NULL,
  line1 text NOT NULL,
  line2 text,
  city text NOT NULL,
  state text NOT NULL,
  pincode text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_addresses" ON addresses;
CREATE POLICY "select_own_addresses" ON addresses FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_addresses" ON addresses;
CREATE POLICY "insert_own_addresses" ON addresses FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_addresses" ON addresses;
CREATE POLICY "update_own_addresses" ON addresses FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_addresses" ON addresses;
CREATE POLICY "delete_own_addresses" ON addresses FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- ORDERS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number text UNIQUE NOT NULL DEFAULT 'TS-' || upper(substr(gen_random_uuid()::text, 1, 8)),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','shipped','delivered','cancelled')),
  subtotal numeric(10,2) NOT NULL,
  shipping_fee numeric(10,2) NOT NULL DEFAULT 0,
  total numeric(10,2) NOT NULL,
  shipping_full_name text NOT NULL,
  shipping_phone text NOT NULL,
  shipping_line1 text NOT NULL,
  shipping_line2 text,
  shipping_city text NOT NULL,
  shipping_state text NOT NULL,
  shipping_pincode text NOT NULL,
  payment_method text NOT NULL DEFAULT 'cod',
  payment_status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS orders_user_idx ON orders(user_id);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_orders" ON orders;
CREATE POLICY "select_own_orders" ON orders FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_orders" ON orders;
CREATE POLICY "insert_own_orders" ON orders FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_orders" ON orders;
CREATE POLICY "update_own_orders" ON orders FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_orders" ON orders;
CREATE POLICY "delete_own_orders" ON orders FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- ORDER ITEMS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE SET NULL,
  product_name text NOT NULL,
  product_image text,
  quantity int NOT NULL CHECK (quantity > 0),
  unit_price numeric(10,2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS order_items_order_idx ON order_items(order_id);

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "select_own_order_items" ON order_items;
CREATE POLICY "select_own_order_items" ON order_items FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()
  ));

DROP POLICY IF EXISTS "insert_own_order_items" ON order_items;
CREATE POLICY "insert_own_order_items" ON order_items FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()
  ));

-- ─────────────────────────────────────────
-- CONTACT SUBMISSIONS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contact_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  phone text,
  subject text,
  message text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE contact_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone_insert_contact" ON contact_submissions;
CREATE POLICY "anyone_insert_contact" ON contact_submissions FOR INSERT
  TO anon, authenticated WITH CHECK (true);

-- ─────────────────────────────────────────
-- SEED DATA — Categories
-- ─────────────────────────────────────────
INSERT INTO categories (name, slug, description, icon, image_url, display_order) VALUES
  ('Mobile Covers', 'mobile-covers', 'Premium protection for your smartphone', 'Smartphone', 'https://images.pexels.com/photos/1092644/pexels-photo-1092644.jpeg', 1),
  ('Chargers', 'chargers', 'Fast & reliable charging solutions', 'Zap', 'https://images.pexels.com/photos/4526414/pexels-photo-4526414.jpeg', 2),
  ('Cables', 'cables', 'Durable cables for every device', 'Cable', 'https://images.pexels.com/photos/3825581/pexels-photo-3825581.jpeg', 3),
  ('Earphones', 'earphones', 'Immersive audio experiences', 'Headphones', 'https://images.pexels.com/photos/3394650/pexels-photo-3394650.jpeg', 4),
  ('Laptop Accessories', 'laptop-accessories', 'Enhance your productivity', 'Laptop', 'https://images.pexels.com/photos/7974/pexels-photo.jpg', 5),
  ('Smartwatches', 'smartwatches', 'Style meets technology on your wrist', 'Watch', 'https://images.pexels.com/photos/437037/pexels-photo-437037.jpeg', 6),
  ('Power Banks', 'power-banks', 'Never run out of battery again', 'BatteryCharging', 'https://images.pexels.com/photos/4526407/pexels-photo-4526407.jpeg', 7),
  ('Other Gadgets', 'other-gadgets', 'Cool gadgets and accessories', 'Cpu', 'https://images.pexels.com/photos/356056/pexels-photo-356056.jpeg', 8)
ON CONFLICT (slug) DO NOTHING;

-- ─────────────────────────────────────────
-- SEED DATA — Products
-- ─────────────────────────────────────────
INSERT INTO products (name, slug, description, price, compare_price, images, category_id, brand, stock_quantity, is_featured, tags, warranty_info) VALUES
  (
    'ShockGuard Pro Case — iPhone 15',
    'shockguard-pro-iphone-15',
    'Military-grade drop protection with a sleek matte finish. Raised bezels protect your screen and camera.',
    699, 1199,
    '["https://images.pexels.com/photos/1092644/pexels-photo-1092644.jpeg","https://images.pexels.com/photos/788946/pexels-photo-788946.jpeg"]',
    (SELECT id FROM categories WHERE slug='mobile-covers'),
    'TS Shield', 50, true,
    ARRAY['iphone','case','protection'], '6 months warranty'
  ),
  (
    'UltraCharge 65W GaN Adapter',
    'ultracharge-65w-gan',
    'Charge your laptop, phone and tablet simultaneously with this compact GaN charger. Universal compatibility.',
    1299, 2199,
    '["https://images.pexels.com/photos/4526414/pexels-photo-4526414.jpeg"]',
    (SELECT id FROM categories WHERE slug='chargers'),
    'TS Power', 30, true,
    ARRAY['charger','gan','fast-charge'], '1 year warranty'
  ),
  (
    'BravoKnit USB-C to USB-C Cable 1.5m',
    'bravoknit-usbc-cable',
    'Nylon braided, 100W PD fast charging cable. Compatible with all USB-C devices.',
    399, 699,
    '["https://images.pexels.com/photos/3825581/pexels-photo-3825581.jpeg"]',
    (SELECT id FROM categories WHERE slug='cables'),
    'TS Link', 100, false,
    ARRAY['cable','usb-c','charging'], '6 months warranty'
  ),
  (
    'BassCore X3 Earphones',
    'basscore-x3-earphones',
    'Deep bass, crystal-clear highs. Ergonomic design for all-day comfort with tangle-free cable.',
    799, 1499,
    '["https://images.pexels.com/photos/3394650/pexels-photo-3394650.jpeg"]',
    (SELECT id FROM categories WHERE slug='earphones'),
    'TS Audio', 45, true,
    ARRAY['earphones','bass','audio'], '6 months warranty'
  ),
  (
    'LapShield Sleeve 15.6" Laptop Bag',
    'lapshield-sleeve-156',
    'Water-resistant neoprene laptop sleeve with accessory pocket. Fits up to 15.6" laptops.',
    899, 1599,
    '["https://images.pexels.com/photos/7974/pexels-photo.jpg"]',
    (SELECT id FROM categories WHERE slug='laptop-accessories'),
    'TS Gear', 25, false,
    ARRAY['laptop','sleeve','bag'], '3 months warranty'
  ),
  (
    'ProFlow Smartwatch Series 3',
    'proflow-smartwatch-s3',
    'Health tracking, call notifications, and 7-day battery life. IP68 waterproof.',
    3499, 5999,
    '["https://images.pexels.com/photos/437037/pexels-photo-437037.jpeg"]',
    (SELECT id FROM categories WHERE slug='smartwatches'),
    'TS Wear', 20, true,
    ARRAY['smartwatch','fitness','waterproof'], '1 year warranty'
  ),
  (
    'PowerVault 20000mAh Power Bank',
    'powervault-20000',
    'Dual USB-A + USB-C output. 22.5W fast charge. LED indicator. Airline approved.',
    1599, 2799,
    '["https://images.pexels.com/photos/4526407/pexels-photo-4526407.jpeg"]',
    (SELECT id FROM categories WHERE slug='power-banks'),
    'TS Power', 40, true,
    ARRAY['powerbank','portable','charging'], '1 year warranty'
  ),
  (
    'MagMount Pro Car Phone Holder',
    'magmount-pro-car-holder',
    'Strong magnetic mount for car dashboard / windshield. Universal compatibility, 360° rotation.',
    599, 999,
    '["https://images.pexels.com/photos/356056/pexels-photo-356056.jpeg"]',
    (SELECT id FROM categories WHERE slug='other-gadgets'),
    'TS Drive', 60, false,
    ARRAY['car','mount','holder'], '3 months warranty'
  ),
  (
    'CrystalArmor Case — Samsung S24',
    'crystalarmor-samsung-s24',
    'Transparent hard-shell case with gold-trim accents. Shows off your phone while protecting it.',
    549, 899,
    '["https://images.pexels.com/photos/1092644/pexels-photo-1092644.jpeg"]',
    (SELECT id FROM categories WHERE slug='mobile-covers'),
    'TS Shield', 70, false,
    ARRAY['samsung','case','clear'], '6 months warranty'
  ),
  (
    'AirPods Case Cover — Leather',
    'airpods-case-leather',
    'Genuine-feel leather protective case for AirPods Pro 2. Carabiner clip included.',
    449, 799,
    '["https://images.pexels.com/photos/788946/pexels-photo-788946.jpeg"]',
    (SELECT id FROM categories WHERE slug='mobile-covers'),
    'TS Shield', 80, false,
    ARRAY['airpods','case','leather'], '3 months warranty'
  )
ON CONFLICT (slug) DO NOTHING;

-- Seed a few reviews for featured products
INSERT INTO reviews (product_id, user_id, rating, title, body, is_verified_purchase)
SELECT
  p.id,
  (SELECT id FROM auth.users LIMIT 1),
  5,
  'Excellent quality!',
  'Really happy with this purchase. Fast delivery and great packaging.',
  true
FROM products p
WHERE p.slug = 'shockguard-pro-iphone-15'
  AND EXISTS (SELECT 1 FROM auth.users LIMIT 1)
ON CONFLICT DO NOTHING;
