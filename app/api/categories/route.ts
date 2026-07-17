import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET() {
  const categories = await prisma.category.findMany({ orderBy: { displayOrder: 'asc' } });
  return NextResponse.json({ categories });
}
