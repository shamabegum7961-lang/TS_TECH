export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface ColorVariant {
  color: string;
  images: string[];
}

export interface Database {
  public: {
    Tables: {
      categories: {
        Row: {
          id: string;
          name: string;
          slug: string;
          description: string | null;
          icon: string | null;
          image_url: string | null;
          display_order: number;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['categories']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['categories']['Insert']>;
      };
      products: {
        Row: {
          id: string;
          name: string;
          slug: string;
          description: string | null;
          price: number;
          compare_price: number | null;
          images: string[];
          category_id: string | null;
          brand: string | null;
          model: string | null;
          color: string | null;
          color_variants: ColorVariant[] | Json;
          in_the_box: string[] | null;
          fast_delivery: boolean;
          is_daily_deal: boolean;
          stock_quantity: number;
          is_featured: boolean;
          is_active: boolean;
          tags: string[] | null;
          warranty_info: string | null;
          specifications: Json;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['products']['Row'], 'id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['products']['Insert']>;
      };
      reviews: {
        Row: {
          id: string;
          product_id: string;
          user_id: string;
          rating: number;
          title: string | null;
          body: string | null;
          is_verified_purchase: boolean;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['reviews']['Row'], 'id' | 'created_at' | 'user_id'>;
        Update: Partial<Database['public']['Tables']['reviews']['Insert']>;
      };
      cart_items: {
        Row: {
          id: string;
          user_id: string;
          product_id: string;
          quantity: number;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['cart_items']['Row'], 'id' | 'created_at' | 'user_id'>;
        Update: Partial<Database['public']['Tables']['cart_items']['Insert']>;
      };
      addresses: {
        Row: {
          id: string;
          user_id: string;
          label: string;
          full_name: string;
          phone: string;
          line1: string;
          line2: string | null;
          city: string;
          state: string;
          pincode: string;
          is_default: boolean;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['addresses']['Row'], 'id' | 'created_at' | 'user_id'>;
        Update: Partial<Database['public']['Tables']['addresses']['Insert']>;
      };
      orders: {
        Row: {
          id: string;
          order_number: string;
          user_id: string;
          status: 'pending' | 'confirmed' | 'shipped' | 'delivered' | 'cancelled';
          subtotal: number;
          shipping_fee: number;
          total: number;
          shipping_full_name: string;
          shipping_phone: string;
          shipping_line1: string;
          shipping_line2: string | null;
          shipping_city: string;
          shipping_state: string;
          shipping_pincode: string;
          payment_method: string;
          payment_status: string;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['orders']['Row'], 'id' | 'order_number' | 'user_id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['orders']['Insert']>;
      };
      order_items: {
        Row: {
          id: string;
          order_id: string;
          product_id: string | null;
          product_name: string;
          product_image: string | null;
          quantity: number;
          unit_price: number;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['order_items']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['order_items']['Insert']>;
      };
      contact_submissions: {
        Row: {
          id: string;
          name: string;
          email: string;
          phone: string | null;
          subject: string | null;
          message: string;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['contact_submissions']['Row'], 'id' | 'created_at'>;
        Update: never;
      };
      wishlists: {
        Row: {
          id: string;
          user_id: string;
          product_id: string;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['wishlists']['Row'], 'id' | 'created_at' | 'user_id'>;
        Update: never;
      };
      daily_deals: {
        Row: {
          id: string;
          product_id: string;
          display_order: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: Omit<Database['public']['Tables']['daily_deals']['Row'], 'id' | 'created_at'>;
        Update: Partial<Database['public']['Tables']['daily_deals']['Insert']>;
      };
    };
    Views: {};
    Functions: {};
    Enums: {};
  };
}

export type Category = Database['public']['Tables']['categories']['Row'];
export type Product = Database['public']['Tables']['products']['Row'];
export type Review = Database['public']['Tables']['reviews']['Row'];
export type CartItem = Database['public']['Tables']['cart_items']['Row'];
export type Address = Database['public']['Tables']['addresses']['Row'];
export type Order = Database['public']['Tables']['orders']['Row'];
export type OrderItem = Database['public']['Tables']['order_items']['Row'];
export type Wishlist = Database['public']['Tables']['wishlists']['Row'];
export type DailyDeal = Database['public']['Tables']['daily_deals']['Row'];

export type ProductWithCategory = Product & { categories: Category | null };
export type CartItemWithProduct = CartItem & { products: Product | null };
export type OrderWithItems = Order & { order_items: (OrderItem & { products: Product | null })[] };
export type WishlistWithProduct = Wishlist & { products: Product | null };
