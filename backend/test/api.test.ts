import "dotenv/config";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import app from "../src/app";
import { prisma } from "../src/prisma";

const email = `api.${Date.now()}@grivinance.local`;
const outsiderEmail = `outsider.${Date.now()}@grivinance.local`;
const password = "rahasia123";

const server = app.listen(0);
const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
let token = "";

async function call(method: string, path: string, body?: unknown) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: res.status, json: (await res.json()) as any };
}

let passed = 0;
const check = (label: string, fn: () => void) => {
  fn();
  console.log(`  ok  ${label}`);
  passed++;
};

/** Saldo wallet dibaca ulang dari API, bukan dari respons transaksi. */
async function balanceOf(walletId: string): Promise<string> {
  const wallets = (await call("GET", "/api/wallets")).json.data;
  return wallets.find((w: any) => w.id === walletId).balance;
}

async function totalTransactions(): Promise<number> {
  return (await call("GET", "/api/transactions")).json.data.pagination.total;
}

async function main() {
  const reg = await call("POST", "/api/auth/register", { email, password, name: "API Test" });
  token = reg.json.data.accessToken;

  // ---------- wallets ----------
  const bca = (
    await call("POST", "/api/wallets", {
      name: "BCA",
      type: "bank",
      icon: "account_balance",
      color: "#3B82F6",
      balance: "0",
    })
  ).json.data;
  check("POST /wallets -> balance string 2 desimal", () => assert.equal(bca.balance, "0.00"));

  const gopay = (
    await call("POST", "/api/wallets", {
      name: "GoPay",
      type: "e_wallet",
      icon: "wallet",
      color: "#10B981",
    })
  ).json.data;

  const badWallet = await call("POST", "/api/wallets", {
    name: "",
    type: "crypto",
    icon: "",
    color: "biru",
  });
  check("POST /wallets payload jelek -> 422", () => assert.equal(badWallet.status, 422));

  const renamed = await call("PUT", `/api/wallets/${bca.id}`, {
    name: "BCA Utama",
    type: "bank",
    icon: "account_balance",
    color: "#3B82F6",
  });
  check("PUT /wallets/:id", () => assert.equal(renamed.json.data.name, "BCA Utama"));

  // ---------- categories ----------
  const cats = (await call("GET", "/api/categories")).json.data;
  check("GET /categories -> 17 preset", () => assert.equal(cats.length, 17));

  const presetEdit = await call("PUT", "/api/categories/cat_makan", {
    name: "Makan Bakar",
    type: "expense",
    icon: "restaurant",
    color: "#F97316",
  });
  check("PUT kategori preset -> 403", () => assert.equal(presetEdit.status, 403));

  const presetDelete = await call("DELETE", "/api/categories/cat_makan");
  check("DELETE kategori preset -> 403", () => assert.equal(presetDelete.status, 403));

  const kopi = (
    await call("POST", "/api/categories", {
      name: "Kopi",
      type: "expense",
      icon: "coffee",
      color: "#A855F7",
    })
  ).json.data;
  check("POST kategori custom -> 201", () => assert.equal(kopi.name, "Kopi"));

  const listAfterCustom = (await call("GET", "/api/categories")).json.data;
  check("GET /categories -> preset + custom", () => assert.equal(listAfterCustom.length, 18));

  // ---------- transaksi: saldo ----------
  const income = (
    await call("POST", "/api/transactions", {
      walletId: bca.id,
      categoryId: "cat_gaji",
      type: "income",
      amount: "150000",
      date: "2026-09-10T10:00:00+07:00",
      note: "Gaji",
    })
  ).json.data;
  check("POST income -> amount string 2 desimal", () => assert.equal(income.amount, "150000.00"));

  const afterIncome = await balanceOf(bca.id);
  check("income 150.000 -> saldo 150000.00", () => assert.equal(afterIncome, "150000.00"));

  const expense = (
    await call("POST", "/api/transactions", {
      walletId: bca.id,
      categoryId: kopi.id,
      type: "expense",
      amount: "50000",
      date: "2026-09-10T12:00:00+07:00",
    })
  ).json.data;

  const afterExpense = await balanceOf(bca.id);
  check("expense 50.000 -> saldo 100000.00", () => assert.equal(afterExpense, "100000.00"));

  const mismatch = await call("POST", "/api/transactions", {
    walletId: bca.id,
    categoryId: "cat_gaji",
    type: "expense",
    amount: "1000",
    date: "2026-09-10T12:00:00+07:00",
  });
  check("kategori income dipakai transaksi expense -> 422", () =>
    assert.equal(mismatch.status, 422),
  );

  const zero = await call("POST", "/api/transactions", {
    walletId: bca.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "0",
    date: "2026-09-10T12:00:00+07:00",
  });
  check("amount 0 -> 422", () => assert.equal(zero.status, 422));

  await call("PUT", `/api/transactions/${expense.id}`, {
    walletId: bca.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "20000",
    date: "2026-09-10T12:00:00+07:00",
  });
  const afterEdit = await balanceOf(bca.id);
  check("update 50rb -> 20rb, saldo 130000.00", () => assert.equal(afterEdit, "130000.00"));

  await call("PUT", `/api/transactions/${expense.id}`, {
    walletId: gopay.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "20000",
    date: "2026-09-10T12:00:00+07:00",
  });
  const bcaAfterMove = await balanceOf(bca.id);
  const gopayAfterMove = await balanceOf(gopay.id);
  check("pindah wallet: BCA balik 150000.00", () => assert.equal(bcaAfterMove, "150000.00"));
  check("pindah wallet: GoPay jadi -20000.00", () => assert.equal(gopayAfterMove, "-20000.00"));

  await call("DELETE", `/api/transactions/${expense.id}`);
  const gopayAfterDelete = await balanceOf(gopay.id);
  check("hapus transaksi: GoPay balik 0.00", () => assert.equal(gopayAfterDelete, "0.00"));

  // ---------- saldo awal ----------
  const freshWallet = (
    await call("POST", "/api/wallets", {
      name: "Kosong",
      type: "cash",
      icon: "payments",
      color: "#6B7280",
      balance: "1000",
    })
  ).json.data;
  check("wallet baru: transactionCount 0", () =>
    assert.equal(freshWallet.transactionCount, 0),
  );

  const editBalance = await call("PUT", `/api/wallets/${freshWallet.id}`, {
    name: "Kosong",
    type: "cash",
    icon: "payments",
    color: "#6B7280",
    balance: "7500",
  });
  check("saldo awal boleh diubah selama belum ada transaksi", () => {
    assert.equal(editBalance.status, 200);
    assert.equal(editBalance.json.data.balance, "7500.00");
  });

  await call("POST", "/api/transactions", {
    walletId: freshWallet.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "500",
    date: "2026-09-10T09:00:00+07:00",
  });

  const blockedBalance = await call("PUT", `/api/wallets/${freshWallet.id}`, {
    name: "Kosong",
    type: "cash",
    icon: "payments",
    color: "#6B7280",
    balance: "9999",
  });
  check("saldo awal ditolak setelah ada transaksi -> 409", () => {
    assert.equal(blockedBalance.status, 409);
    assert.match(blockedBalance.json.message, /saldo awal tidak bisa diubah/);
  });

  const renameOnly = await call("PUT", `/api/wallets/${freshWallet.id}`, {
    name: "Kosong Baru",
    type: "cash",
    icon: "payments",
    color: "#6B7280",
  });
  check("field lain tetap boleh diubah walau ada transaksi", () => {
    assert.equal(renameOnly.status, 200);
    assert.equal(renameOnly.json.data.name, "Kosong Baru");
    assert.equal(renameOnly.json.data.transactionCount, 1);
  });

  await call("DELETE", `/api/wallets/${freshWallet.id}`);

  // ---------- kategori terpakai ----------
  await call("POST", "/api/transactions", {
    walletId: bca.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "5000",
    date: "2026-09-10T13:00:00+07:00",
  });
  const usedDelete = await call("DELETE", `/api/categories/${kopi.id}`);
  check("hapus kategori terpakai -> 409", () => {
    assert.equal(usedDelete.status, 409);
    assert.match(usedDelete.json.message, /masih dipakai di 1 transaksi/);
  });

  // ---------- batas hari WIB ----------
  await call("POST", "/api/transactions", {
    walletId: bca.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "7777",
    date: "2026-09-01T01:00:00+07:00",
    note: "dini hari WIB",
  });

  const sep1 = await call("GET", "/api/summary/daily?date=2026-09-01");
  check("transaksi 01:00 WIB masuk 1 Sep", () =>
    assert.equal(sep1.json.data.totalExpense, "7777.00"),
  );

  const aug31 = await call("GET", "/api/summary/daily?date=2026-08-31");
  check("transaksi 01:00 WIB TIDAK masuk 31 Agu", () =>
    assert.equal(aug31.json.data.totalExpense, "0.00"),
  );

  // ---------- summary ----------
  const monthly = (await call("GET", "/api/summary/monthly?year=2026&month=9")).json.data;
  check("summary bulanan: total income & expense", () => {
    assert.equal(monthly.totalIncome, "150000.00");
    assert.equal(monthly.totalExpense, "12777.00");
  });
  check("summary bulanan: rincian kategori buat donut", () => {
    const row = monthly.byCategory.find((c: any) => c.name === "Kopi");
    assert.equal(row.total, "12777.00");
    assert.equal(row.color, "#A855F7");
    assert.equal(row.type, "expense");
  });

  const yearly = (await call("GET", "/api/summary/yearly?year=2026")).json.data;
  check("summary tahunan: 12 bulan", () => assert.equal(yearly.months.length, 12));
  check("summary tahunan: September terisi, Agustus kosong", () => {
    assert.deepEqual(yearly.months[8], {
      month: 9,
      income: "150000.00",
      expense: "12777.00",
    });
    assert.equal(yearly.months[7].expense, "0.00");
  });

  const badDate = await call("GET", "/api/summary/daily?date=01-09-2026");
  check("summary tanggal format salah -> 422", () => assert.equal(badDate.status, 422));

  // ---------- list, filter, pagination ----------
  const totalNow = await totalTransactions();
  check("GET /transactions -> 3 transaksi", () => assert.equal(totalNow, 3));

  const onlyIncome = await call("GET", "/api/transactions?type=income");
  check("filter type=income -> 1", () => assert.equal(onlyIncome.json.data.pagination.total, 1));

  const byWallet = await call("GET", `/api/transactions?walletId=${gopay.id}`);
  check("filter walletId -> 0", () => assert.equal(byWallet.json.data.pagination.total, 0));

  const paged = await call("GET", "/api/transactions?limit=2&page=1");
  check("pagination limit=2 -> 2 item, 2 halaman", () => {
    assert.equal(paged.json.data.items.length, 2);
    assert.equal(paged.json.data.pagination.totalPages, 2);
  });

  const ranged = await call("GET", "/api/transactions?startDate=2026-09-01&endDate=2026-09-01");
  check("filter tanggal pakai batas WIB -> 1", () =>
    assert.equal(ranged.json.data.pagination.total, 1),
  );

  const relations = paged.json.data.items[0];
  check("item transaksi bawa wallet + kategori", () => {
    assert.ok(relations.wallet.name);
    assert.ok(relations.category.icon);
  });

  // ---------- isolasi antar user ----------
  const mine = token;
  const outsider = await call("POST", "/api/auth/register", {
    email: outsiderEmail,
    password,
    name: "Outsider",
  });
  token = outsider.json.data.accessToken;

  const steal = await call("GET", `/api/transactions/${income.id}`);
  const stealWallet = await call("PUT", `/api/wallets/${bca.id}`, {
    name: "Bajakan",
    type: "bank",
    icon: "account_balance",
    color: "#000000",
  });
  const stealCategory = await call("DELETE", `/api/categories/${kopi.id}`);
  check("user lain baca transaksi -> 404", () => assert.equal(steal.status, 404));
  check("user lain edit wallet -> 404", () => assert.equal(stealWallet.status, 404));
  check("user lain hapus kategori -> 404", () => assert.equal(stealCategory.status, 404));
  token = mine;

  // ---------- hapus wallet ----------
  const before = await totalTransactions();
  await call("DELETE", `/api/wallets/${bca.id}`);
  const after = await totalTransactions();
  check("hapus wallet -> transaksinya ikut hilang", () => {
    assert.equal(before, 3);
    assert.equal(after, 0);
  });

  const myId = reg.json.data.user.id;

  // ---------- BUG-3: field selundupan diabaikan ----------
  const smuggled = await call("PUT", `/api/categories/${kopi.id}`, {
    name: "Kopi",
    type: "expense",
    icon: "coffee",
    color: "#A855F7",
    userId: null,
    isDefault: true,
  });
  const kopiRow = await prisma.category.findUnique({ where: { id: kopi.id } });
  check("PUT kategori + userId:null selundupan -> tetap milik user", () => {
    assert.equal(smuggled.status, 200);
    assert.equal(kopiRow!.userId, myId);
    assert.equal(kopiRow!.isDefault, false);
  });

  const dana = (
    await call("POST", "/api/wallets", {
      name: "DANA",
      type: "e_wallet",
      icon: "logo:dana",
      color: "#3B82F6",
      balance: "100000",
      id: "id-ngarang",
      userId: "orang-lain",
    })
  ).json.data;
  check("POST wallet + id/userId selundupan -> diabaikan", () => {
    assert.notEqual(dana.id, "id-ngarang");
    assert.equal(dana.userId, myId);
  });

  // ---------- BUG-12: input ngawur -> 422, bukan 500 ----------
  const isoFilter = await call("GET", "/api/transactions?startDate=2026-09-01T00:00:00Z");
  const impossible = await call("GET", "/api/summary/daily?date=2026-13-45");
  const huge = await call("POST", "/api/transactions", {
    walletId: dana.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "99999999999999",
    date: "2026-09-20T10:00:00+07:00",
  });
  check("filter ISO penuh / tanggal mustahil / nominal kebesaran -> 422", () => {
    assert.equal(isoFilter.status, 422);
    assert.equal(impossible.status, 422);
    assert.equal(huge.status, 422);
  });

  // ---------- BUG-2: tanggal tanpa offset dibaca WIB ----------
  const offsetless = (
    await call("POST", "/api/transactions", {
      walletId: dana.id,
      categoryId: kopi.id,
      type: "expense",
      amount: "1000",
      date: "2026-09-20T08:00:00.000",
    })
  ).json.data;
  check("tanggal tanpa offset (APK lama) disimpan sebagai jam WIB", () =>
    assert.equal(offsetless.date, "2026-09-20T01:00:00.000Z"),
  );

  // ---------- transfer (REQ-5) ----------
  const bri = (
    await call("POST", "/api/wallets", {
      name: "BRI",
      type: "bank",
      icon: "logo:bri",
      color: "#0EA5E9",
      balance: "500000",
    })
  ).json.data;

  const transferBody = {
    type: "transfer",
    walletId: bri.id,
    toWalletId: dana.id,
    amount: "30000",
    fee: "2500",
    date: "2026-09-20T10:00:00+07:00",
    note: "Top up",
  };
  const transfer = await call("POST", "/api/transactions", transferBody);
  check("transfer -> 201, tanpa kategori, bawa wallet tujuan + biaya", () => {
    assert.equal(transfer.status, 201);
    assert.equal(transfer.json.data.category, null);
    assert.equal(transfer.json.data.toWallet.name, "DANA");
    assert.equal(transfer.json.data.fee, "2500.00");
  });
  const briAfterTransfer = await balanceOf(bri.id);
  const danaAfterTransfer = await balanceOf(dana.id);
  check("saldo: BRI -32.500 (jumlah + biaya), DANA +30.000", () => {
    assert.equal(briAfterTransfer, "467500.00");
    assert.equal(danaAfterTransfer, "129000.00");
  });

  const sepAfterTransfer = (await call("GET", "/api/summary/monthly?year=2026&month=9")).json.data;
  check("summary: transfer nggak dihitung, biaya admin dihitung sebagai pengeluaran", () => {
    assert.equal(sepAfterTransfer.totalIncome, "0.00");
    assert.equal(sepAfterTransfer.totalExpense, "3500.00");
    assert.ok(sepAfterTransfer.byCategory.some((c: any) => c.name === "Biaya Admin"));
  });
  const yearAfterTransfer = (await call("GET", "/api/summary/yearly?year=2026")).json.data;
  check("summary tahunan juga mengabaikan transfer", () =>
    assert.equal(yearAfterTransfer.months[8].expense, "3500.00"),
  );

  const danaHistory = (await call("GET", `/api/transactions?walletId=${dana.id}`)).json.data;
  const onlyTransfers = (await call("GET", "/api/transactions?type=transfer")).json.data;
  check("riwayat wallet tujuan ikut memuat transfer masuk; filter type=transfer", () => {
    assert.equal(danaHistory.pagination.total, 2);
    assert.equal(onlyTransfers.pagination.total, 1);
  });

  const walletsNow = (await call("GET", "/api/wallets")).json.data;
  check("transactionCount wallet tujuan ikut menghitung transfer masuk", () =>
    assert.equal(walletsNow.find((w: any) => w.id === dana.id).transactionCount, 2),
  );

  const feeRow = (await call("GET", `/api/transactions?walletId=${bri.id}`)).json.data.items.find(
    (t: any) => t.feeForId,
  );
  const deleteFee = await call("DELETE", `/api/transactions/${feeRow.id}`);
  check("baris biaya admin nggak bisa dihapus langsung -> 409", () => assert.equal(deleteFee.status, 409));

  const sameWallet = await call("POST", "/api/transactions", { ...transferBody, toWalletId: bri.id });
  check("transfer ke wallet yang sama -> 422", () => assert.equal(sameWallet.status, 422));

  const blockedWalletDelete = await call("DELETE", `/api/wallets/${dana.id}`);
  check("hapus wallet yang terlibat transfer -> 409", () => assert.equal(blockedWalletDelete.status, 409));

  const transferId = transfer.json.data.id;
  const edited = await call("PUT", `/api/transactions/${transferId}`, {
    ...transferBody,
    amount: "50000",
    fee: "",
  });
  const feeLeft = await prisma.transaction.count({ where: { feeForId: transferId } });
  const briAfterEdit = await balanceOf(bri.id);
  const danaAfterEdit = await balanceOf(dana.id);
  check("edit transfer 30rb+biaya -> 50rb tanpa biaya: saldo & baris biaya menyesuaikan", () => {
    assert.equal(edited.json.data.fee, null);
    assert.equal(feeLeft, 0);
    assert.equal(briAfterEdit, "450000.00");
    assert.equal(danaAfterEdit, "149000.00");
  });

  await call("DELETE", `/api/transactions/${transferId}`);
  const briAfterDelete = await balanceOf(bri.id);
  const danaAfterDelete = await balanceOf(dana.id);
  check("hapus transfer -> saldo dua wallet kembali", () => {
    assert.equal(briAfterDelete, "500000.00");
    assert.equal(danaAfterDelete, "99000.00");
  });

  // ---------- BUG-10: tipe kategori terpakai dikunci ----------
  const flipUsed = await call("PUT", `/api/categories/${kopi.id}`, {
    name: "Kopi",
    type: "income",
    icon: "coffee",
    color: "#A855F7",
  });
  check("ganti tipe kategori yang terpakai -> 409", () => assert.equal(flipUsed.status, 409));

  const bonus = (
    await call("POST", "/api/categories", { name: "Bonus", type: "expense", icon: "redeem", color: "#22C55E" })
  ).json.data;
  const flipUnused = await call("PUT", `/api/categories/${bonus.id}`, {
    name: "Bonus",
    type: "income",
    icon: "redeem",
    color: "#22C55E",
  });
  const catsWithUsage = (await call("GET", "/api/categories")).json.data;
  check("tipe kategori yang belum dipakai boleh diganti; list bawa transactionCount", () => {
    assert.equal(flipUnused.status, 200);
    assert.equal(catsWithUsage.find((c: any) => c.id === kopi.id).transactionCount, 1);
  });

  // ---------- budget (REQ-4) ----------
  const setBudget = await call("PUT", `/api/budgets/${kopi.id}`, { amount: "50000" });
  const incomeBudget = await call("PUT", "/api/budgets/cat_gaji", { amount: "1000" });
  check("budget kategori pengeluaran -> 200, kategori pemasukan -> 422", () => {
    assert.equal(setBudget.status, 200);
    assert.equal(incomeBudget.status, 422);
  });

  const budgets = (await call("GET", "/api/budgets?year=2026&month=9")).json.data;
  check("budget September: terpakai & sisa dihitung per bulan WIB", () => {
    assert.equal(budgets.totalBudget, "50000.00");
    assert.equal(budgets.items[0].spent, "1000.00");
    assert.equal(budgets.remaining, "49000.00");
  });

  // ---------- gamifikasi (REQ-4) ----------
  await call("POST", "/api/transactions", {
    walletId: dana.id,
    categoryId: kopi.id,
    type: "expense",
    amount: "500",
    date: new Date().toISOString(),
  });

  const game = (await call("GET", "/api/gamification")).json.data;
  const missionOf = (key: string) => game.missions.find((m: any) => m.key === key);
  check("gamifikasi: lencana yang syaratnya terpenuhi kebuka + XP-nya", () => {
    for (const key of ["first_tx", "first_budget", "wallets_3"]) assert.ok(game.newlyUnlocked.includes(key));
    assert.equal(game.xp, game.newlyUnlocked.length * 50);
    assert.equal(game.level, Math.floor(game.xp / 100) + 1);
  });
  check("misi: catat pengeluaran hari ini selesai; misi jatah muncul karena ada budget", () => {
    assert.equal(missionOf("expense_1").done, true);
    assert.equal(missionOf("expense_1").claimed, false);
    assert.ok(missionOf("under_budget"));
  });

  const notDone = await call("POST", "/api/gamification/missions/records_3/claim");
  const claimed = await call("POST", "/api/gamification/missions/expense_1/claim");
  const twice = await call("POST", "/api/gamification/missions/expense_1/claim");
  const unknown = await call("POST", "/api/gamification/missions/ngarang/claim");
  check("klaim: belum selesai 422, sukses +10 XP, dobel 409, misi ngarang 404", () => {
    assert.equal(notDone.status, 422);
    assert.equal(claimed.status, 200);
    assert.equal(claimed.json.data.xp, game.xp + 10);
    assert.equal(twice.status, 409);
    assert.equal(unknown.status, 404);
  });

  const gameAgain = (await call("GET", "/api/gamification")).json.data;
  check("lencana nggak kebuka dua kali", () => assert.equal(gameAgain.newlyUnlocked.length, 0));

  console.log(`\n${passed} check lolos`);
}

main()
  .catch((e) => {
    console.error("\nGAGAL:", e.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [email, outsiderEmail] } } });
    await prisma.$disconnect();
    server.close();
  });
