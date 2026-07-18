import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getCurrentUser } from '@/lib/auth';
import { serializeProducts, serializeOrder } from '@/lib/serialize';

export async function GET() {
  try {
    const user = await getCurrentUser();
    if (!user?.isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

    const [productCount, orderCount, messageCount, orders, recentOrders, dailyDeals, allProducts] = await Promise.all([
      prisma.product.count(),
      prisma.order.count(),
      prisma.contactSubmission.count(),
      prisma.order.findMany({ where: { status: { not: 'cancelled' } }, select: { total: true } }),
      prisma.order.findMany({ orderBy: { createdAt: 'desc' }, take: 5, select: { orderNumber: true, total: true, status: true, createdAt: true } }),
      prisma.product.findMany({ where: { isDailyDeal: true, isActive: true }, orderBy: { updatedAt: 'desc' } }),
      prisma.product.findMany({ where: { isActive: true }, orderBy: { name: 'asc' } }),
    ]);

    const revenue = orders.reduce((sum, o) => sum + o.total, 0);

    return NextResponse.json({
      productCount, orderCount, messageCount, revenue,
      recentOrders,
      dailyDeals: serializeProducts(dailyDeals as any),
      allProducts: serializeProducts(allProducts as any),
    });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}

export async function PUT(req: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user?.isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

    const { orderNumber } = await req.json();
    const order = await prisma.order.findFirst({
      where: { orderNumber },
      include: { orderItems: { include: { product: { select: { images: true, name: true } } } } },
    });
    return NextResponse.json({ order: order ? serializeOrder(order as any) : null });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}
