'use client';

import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from './AuthContext';
import type { Product } from '@/lib/database.types';

interface WishlistContextValue {
  wishlistIds: string[];
  isInWishlist: (productId: string) => boolean;
  toggleWishlist: (product: Product) => Promise<void>;
  loading: boolean;
}

const WishlistContext = createContext<WishlistContextValue | null>(null);

const LOCAL_KEY = 'ts_tech_wishlist';

export function WishlistProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [wishlistIds, setWishlistIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchWishlist = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    const { data } = await supabase.from('wishlists').select('product_id').eq('user_id', user.id);
    if (data) {
      setWishlistIds(data.map((d) => d.product_id));
    }
    setLoading(false);
  }, [user]);

  useEffect(() => {
    if (user) {
      fetchWishlist();
    } else {
      try {
        const local = JSON.parse(localStorage.getItem(LOCAL_KEY) ?? '[]');
        setWishlistIds(local);
      } catch {
        setWishlistIds([]);
      }
    }
  }, [user, fetchWishlist]);

  const isInWishlist = (productId: string) => wishlistIds.includes(productId);

  const toggleWishlist = async (product: Product) => {
    const isCurrentlyIn = wishlistIds.includes(product.id);
    const next = isCurrentlyIn
      ? wishlistIds.filter((id) => id !== product.id)
      : [...wishlistIds, product.id];

    setWishlistIds(next);

    if (!user) {
      localStorage.setItem(LOCAL_KEY, JSON.stringify(next));
      return;
    }

    if (isCurrentlyIn) {
      await supabase.from('wishlists').delete().eq('user_id', user.id).eq('product_id', product.id);
    } else {
      await supabase.from('wishlists').insert({ product_id: product.id });
    }
  };

  return (
    <WishlistContext.Provider value={{ wishlistIds, isInWishlist, toggleWishlist, loading }}>
      {children}
    </WishlistContext.Provider>
  );
}

export function useWishlist() {
  const ctx = useContext(WishlistContext);
  if (!ctx) throw new Error('useWishlist must be used within WishlistProvider');
  return ctx;
}
