import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getCurrentUser } from '@/lib/auth';

export async function GET() {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ ids: [] });
  const items = await prisma.wishlist.findMany({
    where: { userId: user.id },
    select: { productId: true },
  });
  return NextResponse.json({ ids: items.map((i) => i.productId) });
}

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { productId } = await req.json();
  await prisma.wishlist.upsert({
    where: { userId_productId: { userId: user.id, productId } },
    create: { userId: user.id, productId },
    update: {},
  });
  return NextResponse.json({ success: true });
}

export async function DELETE(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { searchParams } = new URL(req.url);
  const productId = searchParams.get('productId');
  if (!productId) return NextResponse.json({ error: 'Product ID required' }, { status: 400 });

  await prisma.wishlist.deleteMany({ where: { userId: user.id, productId } });
  return NextResponse.json({ success: true });
}
