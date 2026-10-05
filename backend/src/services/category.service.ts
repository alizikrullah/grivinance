import { prisma } from "../prisma";
import { AppError } from "../utils/response.utils";
import type { CategoryType } from "../generated/prisma/enums";

export type CategoryInput = {
  name: string;
  type: CategoryType;
  icon: string;
  color: string;
};

/** Pemakaian dihitung dari transaksi user ini saja — preset dipakai semua user. */
const usageOf = (userId: string) =>
  ({ _count: { select: { transactions: { where: { userId } } } } }) as const;

function toDto({ _count, ...category }: { _count: { transactions: number } } & Record<string, unknown>) {
  return { ...category, transactionCount: _count.transactions };
}

/** Preset global (userId null) tidak boleh disentuh siapa pun. */
async function editableCategory(userId: string, id: string) {
  const category = await prisma.category.findUnique({ where: { id } });
  if (!category) throw new AppError(404, "Kategori tidak ditemukan");
  if (category.userId === null) throw new AppError(403, "Kategori preset tidak bisa diubah");
  if (category.userId !== userId) throw new AppError(404, "Kategori tidak ditemukan");
  return category;
}

export async function list(userId: string) {
  const categories = await prisma.category.findMany({
    where: { OR: [{ userId: null }, { userId }] },
    orderBy: [{ isDefault: "desc" }, { name: "asc" }],
    include: usageOf(userId),
  });
  return categories.map(toDto);
}

export async function create(userId: string, input: CategoryInput) {
  const category = await prisma.category.create({
    data: { name: input.name, type: input.type, icon: input.icon, color: input.color, userId, isDefault: false },
    include: usageOf(userId),
  });
  return toDto(category);
}

export async function update(userId: string, id: string, input: CategoryInput) {
  const category = await editableCategory(userId, id);

  // Aturan "tipe kategori = tipe transaksi" dijaga waktu transaksi dibuat.
  // Kalau tipe kategori yang udah dipakai boleh diganti, semua transaksinya
  // jadi melanggar aturan itu sekaligus (BUG-10). Pola yang sama dengan saldo
  // awal wallet: boleh selama belum dipakai.
  const typeChanged = input.type !== category.type;
  if (typeChanged) {
    const used = await prisma.transaction.count({ where: { categoryId: id } });
    if (used > 0) {
      throw new AppError(409, `Kategori sudah dipakai di ${used} transaksi, tipenya tidak bisa diubah`);
    }
  }

  const updated = await prisma.$transaction(async (db) => {
    // Budget cuma untuk kategori pengeluaran; jadi pemasukan = budgetnya gugur.
    if (typeChanged && input.type === "income") {
      await db.budget.deleteMany({ where: { categoryId: id } });
    }
    return db.category.update({
      where: { id },
      data: { name: input.name, type: input.type, icon: input.icon, color: input.color },
      include: usageOf(userId),
    });
  });
  return toDto(updated);
}

export async function remove(userId: string, id: string) {
  await editableCategory(userId, id);

  const used = await prisma.transaction.count({ where: { categoryId: id } });
  if (used > 0) throw new AppError(409, `Kategori masih dipakai di ${used} transaksi`);

  await prisma.category.delete({ where: { id } });
}
