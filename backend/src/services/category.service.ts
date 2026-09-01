import { prisma } from "../prisma";
import { AppError } from "../utils/response.utils";
import type { CategoryType } from "../generated/prisma/enums";

export type CategoryInput = {
  name: string;
  type: CategoryType;
  icon: string;
  color: string;
};

/** Preset global (userId null) tidak boleh disentuh siapa pun. */
async function editableCategory(userId: string, id: string) {
  const category = await prisma.category.findUnique({ where: { id } });
  if (!category) throw new AppError(404, "Kategori tidak ditemukan");
  if (category.userId === null) throw new AppError(403, "Kategori preset tidak bisa diubah");
  if (category.userId !== userId) throw new AppError(404, "Kategori tidak ditemukan");
  return category;
}

export async function list(userId: string) {
  return prisma.category.findMany({
    where: { OR: [{ userId: null }, { userId }] },
    orderBy: [{ isDefault: "desc" }, { name: "asc" }],
  });
}

export async function create(userId: string, input: CategoryInput) {
  return prisma.category.create({ data: { ...input, userId, isDefault: false } });
}

export async function update(userId: string, id: string, input: Partial<CategoryInput>) {
  await editableCategory(userId, id);
  return prisma.category.update({ where: { id }, data: input });
}

export async function remove(userId: string, id: string) {
  await editableCategory(userId, id);

  const used = await prisma.transaction.count({ where: { categoryId: id } });
  if (used > 0) throw new AppError(409, `Kategori masih dipakai di ${used} transaksi`);

  await prisma.category.delete({ where: { id } });
}
