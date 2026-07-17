import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getCurrentUser } from '@/lib/auth';

export async function GET() {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ membership: null });
  const membership = await prisma.loyaltyMembership.findUnique({ where: { userId: user.id } });
  return NextResponse.json({ membership });
}
