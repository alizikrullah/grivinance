import { prisma } from "../prisma";
import { Prisma } from "../generated/prisma/client";
import { AppError, money } from "../utils/response.utils";
import {
  addDays,
  daysInMonth,
  wibDateKey,
  wibDayRange,
  wibMonthRange,
} from "../utils/date.utils";

const XP_PER_LEVEL = 100;
const ACHIEVEMENT_XP = 50;

/** Seberapa jauh ke belakang streak dihitung. Cukup buat lencana 30 hari dengan sisa banyak. */
const STREAK_WINDOW_DAYS = 400;

const TITLES: Array<[fromLevel: number, title: string]> = [
  [20, "Sultan Hemat"],
  [10, "Penjaga Dompet"],
  [5, "Pencatat Rajin"],
  [1, "Pemula Hemat"],
];

type Stats = {
  today: string;
  streak: number;
  longestStreak: number;
  recordedToday: boolean;
  todayExpenses: number;
  todayRecords: number;
  yesterdayRecords: number;
  yesterdayExpense: Prisma.Decimal;
  /** Total budget bulanan ÷ jumlah hari di bulan kemarin. null = belum ada budget. */
  dailyAllowance: Prisma.Decimal | null;
  totalRecords: number;
  transfers: number;
  wallets: number;
  budgets: number;
  claims: number;
  lastMonthWithinBudget: boolean;
};

type Mission = {
  key: string;
  title: string;
  xp: number;
  visible?: (s: Stats) => boolean;
  done: (s: Stats) => boolean;
  progress: (s: Stats) => { progress: number; target: number };
};

// Harus ada catatan kemarin: tanpa itu, hari yang nggak dicatat sama sekali
// bakal dihitung "hemat" dan misinya gratis.
const underBudgetYesterday = (s: Stats) =>
  s.dailyAllowance !== null && s.yesterdayRecords > 0 && s.yesterdayExpense.lte(s.dailyAllowance);

const MISSIONS: Mission[] = [
  {
    key: "expense_1",
    title: "Catat 1 pengeluaran",
    xp: 10,
    done: (s) => s.todayExpenses >= 1,
    progress: (s) => ({ progress: Math.min(s.todayExpenses, 1), target: 1 }),
  },
  {
    key: "records_3",
    title: "Catat 3 transaksi",
    xp: 20,
    done: (s) => s.todayRecords >= 3,
    progress: (s) => ({ progress: Math.min(s.todayRecords, 3), target: 3 }),
  },
  {
    key: "streak_3",
    title: "Jaga streak 3 hari",
    xp: 15,
    done: (s) => s.streak >= 3,
    progress: (s) => ({ progress: Math.min(s.streak, 3), target: 3 }),
  },
  {
    key: "under_budget",
    title: "Kemarin di bawah jatah",
    xp: 30,
    visible: (s) => s.dailyAllowance !== null,
    done: underBudgetYesterday,
    progress: (s) => ({ progress: underBudgetYesterday(s) ? 1 : 0, target: 1 }),
  },
];

type Achievement = {
  key: string;
  title: string;
  description: string;
  /** Nama Material Icon; Flutter memetakannya lewat AppIcons. */
  icon: string;
  target: number;
  progress: (s: Stats) => number;
};

const ACHIEVEMENTS: Achievement[] = [
  { key: "first_tx", title: "Langkah Pertama", description: "Catat transaksi pertama", icon: "flag", target: 1, progress: (s) => s.totalRecords },
  { key: "tx_100", title: "Rajin Nyatet", description: "Catat 100 transaksi", icon: "edit_note", target: 100, progress: (s) => s.totalRecords },
  { key: "streak_7", title: "Seminggu Penuh", description: "Streak 7 hari", icon: "local_fire_department", target: 7, progress: (s) => s.longestStreak },
  { key: "streak_30", title: "Sebulan Penuh", description: "Streak 30 hari", icon: "whatshot", target: 30, progress: (s) => s.longestStreak },
  { key: "first_budget", title: "Perencana", description: "Atur budget pertama", icon: "pie_chart", target: 1, progress: (s) => s.budgets },
  { key: "budget_month", title: "Bulan Hemat", description: "Sebulan penuh, semua kategori ber-budget tidak lewat", icon: "savings", target: 1, progress: (s) => (s.lastMonthWithinBudget ? 1 : 0) },
  { key: "wallets_3", title: "Multi Dompet", description: "Punya 3 wallet", icon: "account_balance_wallet", target: 3, progress: (s) => s.wallets },
  { key: "first_transfer", title: "Pindah Dana", description: "Transfer antar wallet pertama", icon: "swap_horiz", target: 1, progress: (s) => s.transfers },
  { key: "claims_50", title: "Kolektor Misi", description: "Klaim 50 misi", icon: "emoji_events", target: 50, progress: (s) => s.claims },
];

/** Kolom DATE menyimpan tanggal WIB sebagai tengah malam UTC. */
const dayColumn = (dateKey: string) => new Date(`${dateKey}T00:00:00.000Z`);

function titleOf(level: number) {
  return TITLES.find(([from]) => level >= from)![1];
}

/** Streak berjalan (berakhir hari ini atau kemarin) dan streak terpanjang di jendela. */
function streaksOf(days: Set<string>, today: string) {
  const recordedToday = days.has(today);
  let current = 0;
  for (let d = recordedToday ? today : addDays(today, -1); days.has(d); d = addDays(d, -1)) {
    current++;
  }

  let longest = 0;
  let run = 0;
  let previous: string | null = null;
  for (const day of [...days].sort()) {
    run = previous !== null && addDays(previous, 1) === day ? run + 1 : 1;
    longest = Math.max(longest, run);
    previous = day;
  }

  return { current, longest, recordedToday };
}

/**
 * Bulan WIB kemarin dijalani penuh di bawah budget: ada budget yang berlaku
 * sejak awal bulan itu, ada pengeluaran yang dicatat, dan tidak ada satu pun
 * kategori ber-budget yang lewat.
 */
async function lastMonthWithinBudget(userId: string, today: string) {
  const [year, month] = today.split("-").map(Number) as [number, number];
  const range = month === 1 ? wibMonthRange(year - 1, 12) : wibMonthRange(year, month - 1);

  const budgets = await prisma.budget.findMany({
    where: { userId, createdAt: { lt: range.gte } },
    select: { categoryId: true, amount: true },
  });
  if (budgets.length === 0) return false;

  const spent = await prisma.transaction.groupBy({
    by: ["categoryId"],
    where: { userId, type: "expense", date: range },
    _sum: { amount: true },
  });
  if (spent.length === 0) return false;

  const spentOf = new Map(spent.map((row) => [row.categoryId, row._sum.amount]));
  return budgets.every((b) => new Prisma.Decimal(spentOf.get(b.categoryId) ?? 0).lte(b.amount));
}

async function collectStats(userId: string): Promise<Stats> {
  const today = wibDateKey(new Date());
  const yesterday = addDays(today, -1);

  // Baris biaya admin dibuat otomatis oleh transfer — bukan catatan yang
  // diketik user, jadi nggak dihitung untuk streak dan misi mencatat.
  const ownRecords = { userId, feeForId: null };

  const [recent, totalRecords, transfers, wallets, budgets, claims, todayRows, yesterdayRows, withinBudget] =
    await Promise.all([
      prisma.transaction.findMany({
        where: { ...ownRecords, date: { gte: wibDayRange(addDays(today, -STREAK_WINDOW_DAYS)).gte } },
        select: { date: true },
      }),
      prisma.transaction.count({ where: ownRecords }),
      prisma.transaction.count({ where: { userId, type: "transfer" } }),
      prisma.wallet.count({ where: { userId } }),
      prisma.budget.findMany({ where: { userId }, select: { amount: true } }),
      prisma.missionClaim.count({ where: { userId } }),
      prisma.transaction.findMany({
        where: { userId, date: wibDayRange(today) },
        select: { type: true, feeForId: true },
      }),
      prisma.transaction.findMany({
        where: { userId, date: wibDayRange(yesterday) },
        select: { type: true, feeForId: true, amount: true },
      }),
      lastMonthWithinBudget(userId, today),
    ]);

  const streak = streaksOf(new Set(recent.map((row) => wibDateKey(row.date))), today);

  const totalBudget = budgets.reduce((sum, b) => sum.plus(b.amount), new Prisma.Decimal(0));
  const [yYear, yMonth] = yesterday.split("-").map(Number) as [number, number];

  return {
    today,
    streak: streak.current,
    longestStreak: streak.longest,
    recordedToday: streak.recordedToday,
    todayExpenses: todayRows.filter((r) => r.type === "expense" && !r.feeForId).length,
    todayRecords: todayRows.filter((r) => !r.feeForId).length,
    yesterdayRecords: yesterdayRows.filter((r) => !r.feeForId).length,
    // Biaya admin ikut: itu uang yang beneran keluar kemarin.
    yesterdayExpense: yesterdayRows
      .filter((r) => r.type === "expense")
      .reduce((sum, r) => sum.plus(r.amount), new Prisma.Decimal(0)),
    dailyAllowance: totalBudget.isZero() ? null : totalBudget.div(daysInMonth(yYear, yMonth)),
    totalRecords,
    transfers,
    wallets,
    budgets: budgets.length,
    claims,
    lastMonthWithinBudget: withinBudget,
  };
}

/**
 * Keadaan gamifikasi user, sekaligus membuka lencana yang syaratnya sudah
 * terpenuhi. Membuka lencana idempoten (createMany + skipDuplicates), jadi
 * aman dipanggil berkali-kali; `newlyUnlocked` dipakai Flutter buat animasi.
 */
export async function state(userId: string) {
  const stats = await collectStats(userId);

  const existing = await prisma.userAchievement.findMany({ where: { userId } });
  const owned = new Set(existing.map((a) => a.achievement));
  const fresh = ACHIEVEMENTS.filter((a) => !owned.has(a.key) && a.progress(stats) >= a.target);

  let unlocked = existing;
  if (fresh.length > 0) {
    await prisma.userAchievement.createMany({
      data: fresh.map((a) => ({ userId, achievement: a.key, xp: ACHIEVEMENT_XP })),
      skipDuplicates: true,
    });
    unlocked = await prisma.userAchievement.findMany({ where: { userId } });
  }
  const unlockedOf = new Map(unlocked.map((a) => [a.achievement, a]));

  const [claimXp, claimedToday] = await Promise.all([
    prisma.missionClaim.aggregate({ where: { userId }, _sum: { xp: true } }),
    prisma.missionClaim.findMany({
      where: { userId, day: dayColumn(stats.today) },
      select: { mission: true },
    }),
  ]);
  const claimed = new Set(claimedToday.map((c) => c.mission));

  const xp = (claimXp._sum.xp ?? 0) + unlocked.reduce((sum, a) => sum + a.xp, 0);
  const level = Math.floor(xp / XP_PER_LEVEL) + 1;

  return {
    xp,
    level,
    title: titleOf(level),
    levelXp: xp % XP_PER_LEVEL,
    nextLevelXp: XP_PER_LEVEL,
    streak: {
      current: stats.streak,
      longest: stats.longestStreak,
      recordedToday: stats.recordedToday,
    },
    missions: MISSIONS.filter((m) => m.visible?.(stats) ?? true).map((m) => ({
      key: m.key,
      title: m.title,
      xp: m.xp,
      done: m.done(stats),
      claimed: claimed.has(m.key),
      ...m.progress(stats),
      ...(m.key === "under_budget"
        ? { spent: money(stats.yesterdayExpense), limit: money(stats.dailyAllowance!) }
        : {}),
    })),
    achievements: ACHIEVEMENTS.map((a) => {
      const row = unlockedOf.get(a.key);
      return {
        key: a.key,
        title: a.title,
        description: a.description,
        icon: a.icon,
        xp: ACHIEVEMENT_XP,
        target: a.target,
        // Yang udah kebuka tetap penuh walau datanya kemudian dihapus.
        progress: row ? a.target : Math.min(a.progress(stats), a.target),
        unlocked: Boolean(row),
        unlockedAt: row?.unlockedAt ?? null,
      };
    }),
    newlyUnlocked: fresh.map((a) => a.key),
  };
}

export async function claim(userId: string, key: string) {
  const mission = MISSIONS.find((m) => m.key === key);
  if (!mission) throw new AppError(404, "Misi tidak ditemukan");

  const stats = await collectStats(userId);
  if (!(mission.visible?.(stats) ?? true) || !mission.done(stats)) {
    throw new AppError(422, "Misi belum selesai");
  }

  // Unique (user, misi, hari) yang menjaga satu klaim per hari, bukan cek
  // sebelum insert — dua ketukan cepat nggak bisa dobel klaim.
  const { count } = await prisma.missionClaim.createMany({
    data: [{ userId, mission: key, day: dayColumn(stats.today), xp: mission.xp }],
    skipDuplicates: true,
  });
  if (count === 0) throw new AppError(409, "Misi ini sudah diklaim hari ini");

  return state(userId);
}
