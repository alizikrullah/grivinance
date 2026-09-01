import { prisma } from "../prisma";
import { Prisma } from "../generated/prisma/client";
import { money } from "../utils/response.utils";
import { wibDayRange, wibMonthOf, wibMonthRange, wibYearRange, type DateRange } from "../utils/date.utils";

/** Total income/expense + rincian per kategori dalam satu rentang waktu. */
async function breakdown(userId: string, range: DateRange) {
  const where = { userId, date: range };

  const [grouped, totals] = await Promise.all([
    prisma.transaction.groupBy({
      by: ["categoryId", "type"],
      where,
      _sum: { amount: true },
    }),
    prisma.transaction.groupBy({ by: ["type"], where, _sum: { amount: true } }),
  ]);

  const categories = await prisma.category.findMany({
    where: { id: { in: grouped.map((row) => row.categoryId) } },
    select: { id: true, name: true, icon: true, color: true },
  });
  const byId = new Map(categories.map((c) => [c.id, c]));

  const sumOf = (type: "income" | "expense") =>
    totals.find((row) => row.type === type)?._sum.amount ?? new Prisma.Decimal(0);

  return {
    totalIncome: money(sumOf("income")),
    totalExpense: money(sumOf("expense")),
    byCategory: grouped
      .map((row) => ({
        categoryId: row.categoryId,
        name: byId.get(row.categoryId)?.name ?? "?",
        icon: byId.get(row.categoryId)?.icon ?? "more_horiz",
        color: byId.get(row.categoryId)?.color ?? "#6B7280",
        type: row.type,
        total: money(row._sum.amount ?? 0),
      }))
      .sort((a, b) => Number(b.total) - Number(a.total)),
  };
}

export function daily(userId: string, date: string) {
  return breakdown(userId, wibDayRange(date));
}

export function monthly(userId: string, year: number, month: number) {
  return breakdown(userId, wibMonthRange(year, month));
}

export async function yearly(userId: string, year: number) {
  const rows = await prisma.transaction.findMany({
    where: { userId, date: wibYearRange(year) },
    select: { type: true, amount: true, date: true },
  });

  // ponytail: bucket di JS, bukan 24 query groupBy. Satu tahun transaksi personal
  // muat di memori dengan gampang; pindah ke SQL kalau datanya nanti puluhan ribu.
  const months = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1,
    income: new Prisma.Decimal(0),
    expense: new Prisma.Decimal(0),
  }));

  for (const row of rows) {
    const bucket = months[wibMonthOf(row.date) - 1]!;
    if (row.type === "income") bucket.income = bucket.income.plus(row.amount);
    else bucket.expense = bucket.expense.plus(row.amount);
  }

  return {
    year,
    totalIncome: money(months.reduce((a, m) => a.plus(m.income), new Prisma.Decimal(0))),
    totalExpense: money(months.reduce((a, m) => a.plus(m.expense), new Prisma.Decimal(0))),
    months: months.map((m) => ({
      month: m.month,
      income: money(m.income),
      expense: money(m.expense),
    })),
  };
}
