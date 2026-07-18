import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getCurrentUser } from '@/lib/auth';
import { serializeProduct, serializeProducts } from '@/lib/serialize';

export async function GET() {
  try {
    const user = await getCurrentUser();
    if (!user?.isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

    const products = await prisma.product.findMany({
      orderBy: { createdAt: 'desc' },
      include: { category: true },
    });
    return NextResponse.json({ products: serializeProducts(products as any) });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}

export async function PUT(req: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user?.isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

    const { id, data } = await req.json();
    const { categoryId, images, tags, inTheBox, specifications, colorVariants, ...rest } = data;

    const prepared: Record<string, unknown> = {
      ...rest,
      images: JSON.stringify(images ?? []),
      tags: JSON.stringify(tags ?? []),
      inTheBox: JSON.stringify(inTheBox ?? []),
      specifications: JSON.stringify(specifications ?? {}),
      ...(colorVariants != null ? { colorVariants: JSON.stringify(colorVariants) } : {}),
      ...(categoryId ? { category: { connect: { id: categoryId } } } : {}),
    };

    const product = await prisma.product.update({
      where: { id },
      data: prepared as any,
      include: { category: true },
    });
    return NextResponse.json({ product: serializeProduct(product as any) });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user?.isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');
    if (!id) return NextResponse.json({ error: 'ID required' }, { status: 400 });

    await prisma.product.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}
