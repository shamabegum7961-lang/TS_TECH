import type { Product, Category, Review, CartItem, Order, OrderItem } from '@/lib/database.types';

type CategoryInput = Omit<Category, 'createdAt'> & { createdAt: Date | string };

type ProductWithCategory = Product & { category: Category | null };

function safeParse<T>(value: unknown, fallback: T): T {
  if (value == null) return fallback;
  if (typeof value !== 'string') return value as T;
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
}

export function serializeProduct(p: {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  price: any;
  comparePrice: any;
  images: unknown;
  categoryId: string | null;
  brand: string | null;
  model: string | null;
  color: string | null;
  colorVariants: unknown;
  inTheBox: unknown;
  fastDelivery: boolean;
  isDailyDeal: boolean;
  stockQuantity: number;
  isFeatured: boolean;
  isActive: boolean;
  tags: unknown;
  warrantyInfo: string | null;
  specifications: unknown;
  createdAt: Date | string;
  updatedAt: Date | string;
  category?: CategoryInput | null;
}): ProductWithCategory {
  return {
    ...p,
    price: Number(p.price),
    comparePrice: p.comparePrice == null ? null : Number(p.comparePrice),
    images: safeParse<string[]>(p.images, []),
    colorVariants: safeParse<unknown>(p.colorVariants, null),
    inTheBox: safeParse<string[]>(p.inTheBox, []),
    tags: safeParse<string[]>(p.tags, []),
    specifications: safeParse<unknown>(p.specifications, {}),
    createdAt: p.createdAt instanceof Date ? p.createdAt.toISOString() : p.createdAt,
    updatedAt: p.updatedAt instanceof Date ? p.updatedAt.toISOString() : p.updatedAt,
    category: p.category
      ? {
          ...p.category,
          createdAt: p.category.createdAt instanceof Date ? p.category.createdAt.toISOString() : p.category.createdAt,
        }
      : null,
  };
}

export function serializeProducts(products: Parameters<typeof serializeProduct>[0][]): ProductWithCategory[] {
  return products.map(serializeProduct);
}

export function serializeCategory(c: {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  icon: string | null;
  imageUrl: string | null;
  displayOrder: number;
  createdAt: Date | string;
}): Category {
  return {
    ...c,
    createdAt: c.createdAt instanceof Date ? c.createdAt.toISOString() : c.createdAt,
  };
}

export function serializeReview(r: {
  id: string;
  productId: string;
  userId: string;
  rating: number;
  title: string | null;
  body: string | null;
  isVerifiedPurchase: boolean;
  createdAt: Date | string;
  user?: { fullName: string | null } | null;
}): Review {
  return {
    ...r,
    createdAt: r.createdAt instanceof Date ? r.createdAt.toISOString() : r.createdAt,
  };
}

export function serializeCartItem(c: {
  id: string;
  userId: string;
  productId: string;
  quantity: number;
  createdAt: Date | string;
  product?: Parameters<typeof serializeProduct>[0] | null;
}): CartItem & { product: Product | null } {
  return {
    ...c,
    createdAt: c.createdAt instanceof Date ? c.createdAt.toISOString() : c.createdAt,
    product: c.product ? serializeProduct(c.product) : null,
  };
}

export function serializeOrderItem(oi: {
  id: string;
  orderId: string;
  productId: string | null;
  productName: string;
  productImage: string | null;
  quantity: number;
  unitPrice: any;
  createdAt: Date | string;
  product?: { images: unknown; name: string } | null;
}): OrderItem {
  return {
    ...oi,
    unitPrice: Number(oi.unitPrice),
    createdAt: oi.createdAt instanceof Date ? oi.createdAt.toISOString() : oi.createdAt,
    product: oi.product
      ? { images: safeParse<string[]>(oi.product.images, []), name: oi.product.name }
      : null,
  };
}

export function serializeOrder(o: {
  id: string;
  orderNumber: string;
  userId: string;
  status: Order['status'];
  subtotal: any;
  shippingFee: any;
  total: any;
  pointsRedeemed: number;
  loyaltyDiscount: any;
  shippingFullName: string;
  shippingPhone: string;
  shippingLine1: string;
  shippingLine2: string | null;
  shippingCity: string;
  shippingState: string;
  shippingPincode: string;
  paymentMethod: string;
  paymentStatus: string;
  notes: string | null;
  createdAt: Date | string;
  updatedAt: Date | string;
  orderItems?: Parameters<typeof serializeOrderItem>[0][];
}): Order & { orderItems: OrderItem[] } {
  return {
    ...o,
    subtotal: Number(o.subtotal),
    shippingFee: Number(o.shippingFee),
    total: Number(o.total),
    loyaltyDiscount: Number(o.loyaltyDiscount),
    createdAt: o.createdAt instanceof Date ? o.createdAt.toISOString() : o.createdAt,
    updatedAt: o.updatedAt instanceof Date ? o.updatedAt.toISOString() : o.updatedAt,
    orderItems: o.orderItems ? o.orderItems.map(serializeOrderItem) : [],
  };
}

export function parseJsonInput<T>(value: T): T {
  return value;
}

export function stringifyJsonField(value: unknown): string {
  if (value == null) return '[]';
  if (typeof value === 'string') {
    try {
      JSON.parse(value);
      return value;
    } catch {
      return JSON.stringify(value);
    }
  }
  return JSON.stringify(value);
}
