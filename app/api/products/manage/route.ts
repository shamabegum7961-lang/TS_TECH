import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getCurrentUser } from '@/lib/auth';
import { serializeProduct, serializeProducts } from '@/lib/serialize';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const productIds = searchParams.get('ids');
    const slugCheck = searchParams.get('slug_check');

    if (slugCheck) {
      const existing = await prisma.product.findUnique({ where: { slug: slugCheck }, select: { slug: true } });
      return NextResponse.json({ exists: !!existing });
    }

    if (productIds) {
      const ids = productIds.split(',').filter(Boolean);
      if (ids.length === 0) return NextResponse.json({ products: [] });
      const products = await prisma.product.findMany({
        where: { id: { in: ids }, isActive: true },
        include: { category: true },
      });
      return NextResponse.json({ products: serializeProducts(products as any) });
    }

    const product = await prisma.product.findUnique({
      where: { id: searchParams.get('id') ?? '' },
      include: { category: true },
    });
    return NextResponse.json({ product: product ? serializeProduct(product as any) : null });
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
    if (!id) return NextResponse.json({ error: 'Product ID required' }, { status: 400 });

    await prisma.product.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}
