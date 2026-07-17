'use client';

import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from './AuthContext';
import type { Product } from '@/lib/database.types';

export interface LocalCartItem {
  product: Product;
  quantity: number;
}

interface CartContextValue {
  items: LocalCartItem[];
  count: number;
  total: number;
  loading: boolean;
  addToCart: (product: Product, quantity?: number) => Promise<void>;
  removeFromCart: (productId: string) => Promise<void>;
  updateQuantity: (productId: string, quantity: number) => Promise<void>;
  clearCart: () => Promise<void>;
}

const CartContext = createContext<CartContextValue | null>(null);

const LOCAL_KEY = 'ts_tech_cart';

function readLocal(): LocalCartItem[] {
  if (typeof window === 'undefined') return [];
  try {
    return JSON.parse(localStorage.getItem(LOCAL_KEY) ?? '[]');
  } catch {
    return [];
  }
}

function saveLocal(items: LocalCartItem[]) {
  localStorage.setItem(LOCAL_KEY, JSON.stringify(items));
}

export function CartProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [items, setItems] = useState<LocalCartItem[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchServerCart = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('cart_items')
      .select('*, products(*)')
      .eq('user_id', user.id);
    if (!error && data) {
      const mapped: LocalCartItem[] = data
        .filter((d) => d.products)
        .map((d) => ({ product: d.products as Product, quantity: d.quantity }));
      setItems(mapped);
      saveLocal(mapped);
    }
    setLoading(false);
  }, [user]);

  useEffect(() => {
    if (user) {
      fetchServerCart();
    } else {
      setItems(readLocal());
    }
  }, [user, fetchServerCart]);

  const addToCart = async (product: Product, quantity = 1) => {
    setItems((prev) => {
      const existing = prev.find((i) => i.product.id === product.id);
      const next = existing
        ? prev.map((i) => i.product.id === product.id ? { ...i, quantity: i.quantity + quantity } : i)
        : [...prev, { product, quantity }];
      saveLocal(next);
      return next;
    });

    if (user) {
      const current = items.find((i) => i.product.id === product.id);
      if (current) {
        await supabase.from('cart_items').update({ quantity: current.quantity + quantity }).eq('user_id', user.id).eq('product_id', product.id);
      } else {
        await supabase.from('cart_items').upsert({ product_id: product.id, quantity }, { onConflict: 'user_id,product_id' });
      }
    }
  };

  const removeFromCart = async (productId: string) => {
    setItems((prev) => {
      const next = prev.filter((i) => i.product.id !== productId);
      saveLocal(next);
      return next;
    });
    if (user) {
      await supabase.from('cart_items').delete().eq('user_id', user.id).eq('product_id', productId);
    }
  };

  const updateQuantity = async (productId: string, quantity: number) => {
    if (quantity <= 0) { await removeFromCart(productId); return; }
    setItems((prev) => {
      const next = prev.map((i) => i.product.id === productId ? { ...i, quantity } : i);
      saveLocal(next);
      return next;
    });
    if (user) {
      await supabase.from('cart_items').update({ quantity }).eq('user_id', user.id).eq('product_id', productId);
    }
  };

  const clearCart = async () => {
    setItems([]);
    saveLocal([]);
    if (user) {
      await supabase.from('cart_items').delete().eq('user_id', user.id);
    }
  };

  const count = items.reduce((s, i) => s + i.quantity, 0);
  const total = items.reduce((s, i) => s + i.product.price * i.quantity, 0);

  return (
    <CartContext.Provider value={{ items, count, total, loading, addToCart, removeFromCart, updateQuantity, clearCart }}>
      {children}
    </CartContext.Provider>
  );
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within CartProvider');
  return ctx;
}
