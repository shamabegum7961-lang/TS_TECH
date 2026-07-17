'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';

export default function AuthCallbackPage() {
  const router = useRouter();

  useEffect(() => {
    const handleCallback = async () => {
      const { error } = await supabase.auth.exchangeCodeForSession(window.location.search);
      if (error) {
        console.error('Auth callback error:', error);
        router.replace('/login?error=auth_callback_failed');
      } else {
        router.replace('/account');
      }
    };
    handleCallback();
  }, [router]);

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="flex flex-col items-center gap-4">
        <div className="w-8 h-8 rounded-full border-2 border-gold-500 border-t-transparent animate-spin" />
        <p className="text-silver-400 text-sm">Completing sign in...</p>
      </div>
    </div>
  );
}
