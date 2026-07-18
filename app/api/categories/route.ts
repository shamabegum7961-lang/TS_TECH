import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { serializeCategory } from '@/lib/serialize';

export async function GET() {
  try {
    const categories = await prisma.category.findMany({ orderBy: { displayOrder: 'asc' } });
    return NextResponse.json({ categories: categories.map(serializeCategory) });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Internal server error' }, { status: 500 });
  }
}
