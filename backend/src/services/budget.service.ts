import { prisma } from "../prisma";
import { Prisma } from "../generated/prisma/client";
import { AppError, money } from "../utils/response.utils";
import { wibMonthRange } from "../utils/date.utils";

/**
 * Budget per kategori pengeluaran untuk satu bulan WIB. Angka budgetnya
 * berlaku tiap bulan; yang dihitung ulang per bulan cuma terpakainya.
 */
export async function list(userId: string, year: number, month: number) {
  const budgets = await prisma.budget.findMany({
    where: { userId },
    include: { category: { select: { name: true, icon: true, color: true } } },
    orderBy: { createdAt: "asc" },
  });

  // Biaya admin transfer ikut menghabiskan budget kategori "Biaya Admin" —
  // itu pengeluaran sungguhan. Transfernya sendiri tidak, karena bukan expense.
  const spentRows = await prisma.transaction.groupBy({
    by: ["categoryId"],
    where: {
      userId,
      type: "expense",
      date: wibMonthRange(year, month),
      categoryId: { in: budgets.map((b) => b.categoryId) },
    },
    _sum: { amount: true },
  });
  const spentOf = new Map(spentRows.map((row) => [row.categoryId, row._sum.amount]));

  let totalBudget = new Prisma.Decimal(0);
  let totalSpent = new Prisma.Decimal(0);

  const items = budgets.map((budget) => {
    const spent = new Prisma.Decimal(spentOf.get(budget.categoryId) ?? 0);
    totalBudget = totalBudget.plus(budget.amount);
    totalSpent = totalSpent.plus(spent);
    return {
      categoryId: budget.categoryId,
      ...budget.category,
      amount: money(budget.amount),
      spent: money(spent),
      remaining: money(budget.amount.minus(spent)),
    };
  });

  return {
    year,
    month,
    totalBudget: money(totalBudget),
    totalSpent: money(totalSpent),
    remaining: money(totalBudget.minus(totalSpent)),
    items,
  };
}

export async function set(userId: string, categoryId: string, amount: string) {
  const category = await prisma.category.findFirst({
    where: { id: categoryId, OR: [{ userId: null }, { userId }] },
  });
  if (!category) throw new AppError(404, "Kategori tidak ditemukan");
  if (category.type !== "expense") {
    throw new AppError(422, "Budget cuma bisa diatur untuk kategori pengeluaran");
  }

  const budget = await prisma.budget.upsert({
    where: { userId_categoryId: { userId, categoryId } },
    create: { userId, categoryId, amount },
    update: { amount },
  });
  return { categoryId, amount: money(budget.amount) };
}

export async function remove(userId: string, categoryId: string) {
  await prisma.budget.deleteMany({ where: { userId, categoryId } });
}
