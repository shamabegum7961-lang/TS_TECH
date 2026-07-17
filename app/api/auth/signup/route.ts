import { NextRequest, NextResponse } from 'next/server';
import { signUp } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const { email, password, fullName, referralCode } = await req.json();
    if (!email || !password) {
      return NextResponse.json({ error: 'Email and password are required' }, { status: 400 });
    }
    if (password.length < 6) {
      return NextResponse.json({ error: 'Password must be at least 6 characters' }, { status: 400 });
    }
    const user = await signUp(email, password, fullName || email.split('@')[0]);
    return NextResponse.json({ user });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Sign up failed';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
