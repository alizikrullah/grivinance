import { prisma } from "../prisma";
import { Prisma } from "../generated/prisma/client";
import type { TransactionType } from "../generated/prisma/enums";
import { AppError, money } from "../utils/response.utils";
import { parseClientDate, wibDayRange } from "../utils/date.utils";

/** Kategori preset tempat biaya admin transfer dicatat. Id-nya di-hardcode di seed. */
export const FEE_CATEGORY_ID = "cat_biaya_admin";

export type TransactionInput = {
  type: TransactionType;
  walletId: string;
  toWalletId?: string;
  categoryId?: string;
  amount: string;
  fee?: string;
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

const ref = { select: { id: true, name: true, icon: true, color: true, type: true } } as const;

const withRelations = {
  wallet: ref,
  toWallet: ref,
  category: ref,
  fee: { select: { id: true, amount: true } },
} as const;

type Row = Prisma.TransactionGetPayload<{ include: typeof withRelations }>;

/** Biaya admin ikut ditempel ke transfernya supaya form edit bisa menampilkannya. */
function toDto({ fee, ...tx }: Row) {
  return { ...tx, amount: money(tx.amount), fee: fee ? money(fee.amount) : null };
}

/** Bagian baris yang menentukan pengaruhnya ke saldo. */
type BalanceRow = {
  type: TransactionType;
  walletId: string;
  toWalletId: string | null;
  amount: Prisma.Decimal;
};

/**
 * Pengaruh satu baris ke saldo wallet. Ini satu-satunya tempat tanda +/−
 * ditentukan: income menambah, expense mengurangi, transfer memindahkan.
 */
function effectsOf(row: BalanceRow): Array<[walletId: string, delta: Prisma.Decimal]> {
  const amount = new Prisma.Decimal(row.amount);
  switch (row.type) {
    case "income":
      return [[row.walletId, amount]];
    case "expense":
      return [[row.walletId, amount.neg()]];
    case "transfer":
      return [
        [row.walletId, amount.neg()],
        [row.toWalletId!, amount],
      ];
  }
}

type Change = [row: BalanceRow, sign: 1 | -1];

/**
 * Terapkan (+1) atau batalkan (−1) pengaruh sekumpulan baris ke saldo.
 * Update = batalkan baris lama + terapkan baris baru dalam satu panggilan,
 * jadi pindah wallet, ganti tipe, dan ganti biaya admin semuanya lewat jalur
 * yang sama tanpa kasus khusus.
 */
async function applyEffects(db: Prisma.TransactionClient, changes: Change[]) {
  const totals = new Map<string, Prisma.Decimal>();
  for (const [row, sign] of changes) {
    for (const [walletId, delta] of effectsOf(row)) {
      const signed = sign === 1 ? delta : delta.neg();
      totals.set(walletId, (totals.get(walletId) ?? new Prisma.Decimal(0)).plus(signed));
    }
  }

  for (const [walletId, delta] of totals) {
    if (delta.isZero()) continue;
    await db.wallet.update({ where: { id: walletId }, data: { balance: { increment: delta } } });
  }
}

async function assertReferences(userId: string, input: TransactionInput) {
  const ownWallet = async (id: string) => {
    const wallet = await prisma.wallet.findFirst({ where: { id, userId } });
    if (!wallet) throw new AppError(404, "Wallet tidak ditemukan");
  };

  await ownWallet(input.walletId);

  if (input.type === "transfer") {
    if (!input.toWalletId) throw new AppError(422, "Wallet tujuan wajib dipilih");
    if (input.toWalletId === input.walletId) {
      throw new AppError(422, "Wallet asal dan tujuan tidak boleh sama");
    }
    await ownWallet(input.toWalletId);
    return;
  }

  if (!input.categoryId) throw new AppError(422, "Kategori wajib dipilih");
  const category = await prisma.category.findFirst({
    where: { id: input.categoryId, OR: [{ userId: null }, { userId }] },
  });
  if (!category) throw new AppError(404, "Kategori tidak ditemukan");

  if (category.type !== input.type) {
    throw new AppError(422, `Kategori "${category.name}" bertipe ${category.type}, tidak cocok dengan transaksi ${input.type}`);
  }
}

/** Baris utama dari input: transfer tanpa kategori, income/expense tanpa wallet tujuan. */
function mainRow(input: TransactionInput) {
  const isTransfer = input.type === "transfer";
  return {
    type: input.type,
    walletId: input.walletId,
    toWalletId: isTransfer ? input.toWalletId! : null,
    categoryId: isTransfer ? null : input.categoryId!,
    amount: new Prisma.Decimal(input.amount),
    note: input.note?.trim() || null,
    date: parseClientDate(input.date),
  };
}

/** Biaya admin transfer: expense terpisah dari wallet asal, di tanggal yang sama. */
function feeRow(input: TransactionInput, date: Date) {
  if (input.type !== "transfer" || !input.fee) return null;
  const amount = new Prisma.Decimal(input.fee);
  if (amount.isZero()) return null;
  return {
    type: "expense" as const,
    walletId: input.walletId,
    toWalletId: null,
    categoryId: FEE_CATEGORY_ID,
    amount,
    note: null,
    date,
  };
}

/** Baris yang boleh diubah/dihapus user, beserta biaya adminnya kalau ada. */
async function editableTransaction(userId: string, id: string) {
  const tx = await prisma.transaction.findFirst({ where: { id, userId }, include: { fee: true } });
  if (!tx) throw new AppError(404, "Transaksi tidak ditemukan");
  if (tx.feeForId) {
    throw new AppError(409, "Biaya admin ini bagian dari transfer. Ubah atau hapus lewat transfernya");
  }
  return tx;
}

export async function list(userId: string, filter: TransactionFilter) {
  const page = Math.max(1, filter.page ?? 1);
  const limit = Math.min(100, Math.max(1, filter.limit ?? 20));

  const where: Prisma.TransactionWhereInput = { userId };
  // Riwayat sebuah wallet termasuk transfer yang masuk ke dia.
  if (filter.walletId) where.OR = [{ walletId: filter.walletId }, { toWalletId: filter.walletId }];
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
  await assertReferences(userId, input);

  const main = mainRow(input);
  const fee = feeRow(input, main.date);

  const changes: Change[] = [[main, 1]];
  if (fee) changes.push([fee, 1]);

  const id = await prisma.$transaction(async (db) => {
    const tx = await db.transaction.create({ data: { ...main, userId } });
    if (fee) await db.transaction.create({ data: { ...fee, userId, feeForId: tx.id } });

    await applyEffects(db, changes);
    return tx.id;
  });

  return detail(userId, id);
}

export async function update(userId: string, id: string, input: TransactionInput) {
  const old = await editableTransaction(userId, id);
  await assertReferences(userId, input);

  const main = mainRow(input);
  const fee = feeRow(input, main.date);

  const changes: Change[] = [[old, -1], [main, 1]];
  if (old.fee) changes.push([old.fee, -1]);
  if (fee) changes.push([fee, 1]);

  await prisma.$transaction(async (db) => {
    // Biaya lama dibuang lalu dibuat ulang sesuai input: lebih sederhana dari
    // membedakan tambah/ubah/hapus biaya, dan saldonya tetap benar karena
    // pengaruh baris lama dibatalkan di applyEffects.
    if (old.fee) await db.transaction.delete({ where: { id: old.fee.id } });
    await db.transaction.update({ where: { id }, data: main });
    if (fee) await db.transaction.create({ data: { ...fee, userId, feeForId: id } });

    await applyEffects(db, changes);
  });

  return detail(userId, id);
}

export async function remove(userId: string, id: string) {
  const old = await editableTransaction(userId, id);

  const changes: Change[] = [[old, -1]];
  if (old.fee) changes.push([old.fee, -1]);

  await prisma.$transaction(async (db) => {
    // Biaya admin ikut terhapus lewat FK fee_for_id (Cascade); saldonya
    // dikembalikan di sini karena cascade di database nggak menyentuh saldo.
    await db.transaction.delete({ where: { id } });
    await applyEffects(db, changes);
  });
}
