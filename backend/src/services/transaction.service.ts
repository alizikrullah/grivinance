import { prisma } from "../prisma";
import { Prisma } from "../generated/prisma/client";
import type { TransactionType } from "../generated/prisma/enums";
import { AppError, money } from "../utils/response.utils";
import { wibDayRange } from "../utils/date.utils";

export type TransactionInput = {
  walletId: string;
  categoryId: string;
  type: TransactionType;
  amount: string;
  note?: string | null;
  date: string;
};

export type TransactionFilter = {
  page?: number;
  limit?: number;
  walletId?: string;
  categoryId?: string;
  type?: TransactionType;
  startDate?: string;
  endDate?: string;
};

const withRelations = {
  wallet: { select: { id: true, name: true, icon: true, color: true, type: true } },
  category: { select: { id: true, name: true, icon: true, color: true, type: true } },
} as const;

type TransactionRow = { amount: unknown } & Record<string, unknown>;

const toDto = (tx: TransactionRow) => ({ ...tx, amount: money(tx.amount as string) });

/** income nambah saldo, expense ngurangin. Ini satu-satunya tempat tanda itu ditentukan. */
function signedAmount(type: TransactionType, amount: Prisma.Decimal) {
  return type === "income" ? amount : amount.neg();
}

async function assertWalletAndCategory(userId: string, input: Pick<TransactionInput, "walletId" | "categoryId" | "type">) {
  const wallet = await prisma.wallet.findFirst({ where: { id: input.walletId, userId } });
  if (!wallet) throw new AppError(404, "Wallet tidak ditemukan");

  const category = await prisma.category.findFirst({
    where: { id: input.categoryId, OR: [{ userId: null }, { userId }] },
  });
  if (!category) throw new AppError(404, "Kategori tidak ditemukan");

  if (category.type !== input.type) {
    throw new AppError(422, `Kategori "${category.name}" bertipe ${category.type}, tidak cocok dengan transaksi ${input.type}`);
  }
}

async function ownedTransaction(userId: string, id: string) {
  const tx = await prisma.transaction.findFirst({ where: { id, userId } });
  if (!tx) throw new AppError(404, "Transaksi tidak ditemukan");
  return tx;
}

export async function list(userId: string, filter: TransactionFilter) {
  const page = Math.max(1, filter.page ?? 1);
  const limit = Math.min(100, Math.max(1, filter.limit ?? 20));

  const where: Prisma.TransactionWhereInput = { userId };
  if (filter.walletId) where.walletId = filter.walletId;
  if (filter.categoryId) where.categoryId = filter.categoryId;
  if (filter.type) where.type = filter.type;

  // Batas tanggal ikut hari WIB, bukan UTC.
  if (filter.startDate || filter.endDate) {
    where.date = {
      ...(filter.startDate ? { gte: wibDayRange(filter.startDate).gte } : {}),
      ...(filter.endDate ? { lt: wibDayRange(filter.endDate).lt } : {}),
    };
  }

  const [items, total] = await Promise.all([
    prisma.transaction.findMany({
      where,
      include: withRelations,
      orderBy: [{ date: "desc" }, { createdAt: "desc" }],
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.transaction.count({ where }),
  ]);

  return {
    items: items.map(toDto),
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };
}

export async function detail(userId: string, id: string) {
  const tx = await prisma.transaction.findFirst({ where: { id, userId }, include: withRelations });
  if (!tx) throw new AppError(404, "Transaksi tidak ditemukan");
  return toDto(tx);
}

export async function create(userId: string, input: TransactionInput) {
  await assertWalletAndCategory(userId, input);

  const delta = signedAmount(input.type, new Prisma.Decimal(input.amount));

  const [tx] = await prisma.$transaction([
    prisma.transaction.create({
      data: {
        userId,
        walletId: input.walletId,
        categoryId: input.categoryId,
        type: input.type,
        amount: input.amount,
        note: input.note ?? null,
        date: new Date(input.date),
      },
      include: withRelations,
    }),
    prisma.wallet.update({
      where: { id: input.walletId },
      data: { balance: { increment: delta } },
    }),
  ]);

  return toDto(tx);
}

export async function update(userId: string, id: string, input: TransactionInput) {
  const old = await ownedTransaction(userId, id);
  await assertWalletAndCategory(userId, input);

  const oldDelta = signedAmount(old.type, new Prisma.Decimal(old.amount));
  const newDelta = signedAmount(input.type, new Prisma.Decimal(input.amount));

  // Balance lama di-reverse dulu, baru yang baru diterapkan. Kalau wallet-nya
  // pindah, dua wallet berbeda yang harus disentuh.
  const balanceOps =
    old.walletId === input.walletId
      ? [
          prisma.wallet.update({
            where: { id: input.walletId },
            data: { balance: { increment: newDelta.minus(oldDelta) } },
          }),
        ]
      : [
          prisma.wallet.update({
            where: { id: old.walletId },
            data: { balance: { decrement: oldDelta } },
          }),
          prisma.wallet.update({
            where: { id: input.walletId },
            data: { balance: { increment: newDelta } },
          }),
        ];

  const [tx] = await prisma.$transaction([
    prisma.transaction.update({
      where: { id },
      data: {
        walletId: input.walletId,
        categoryId: input.categoryId,
        type: input.type,
        amount: input.amount,
        note: input.note ?? null,
        date: new Date(input.date),
      },
      include: withRelations,
    }),
    ...balanceOps,
  ]);

  return toDto(tx);
}

export async function remove(userId: string, id: string) {
  const tx = await ownedTransaction(userId, id);
  const delta = signedAmount(tx.type, new Prisma.Decimal(tx.amount));

  await prisma.$transaction([
    prisma.transaction.delete({ where: { id } }),
    prisma.wallet.update({
      where: { id: tx.walletId },
      data: { balance: { decrement: delta } },
    }),
  ]);
}
