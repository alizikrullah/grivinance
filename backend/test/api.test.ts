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
  check("GET /categories -> 16 preset", () => assert.equal(cats.length, 16));

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
  check("GET /categories -> preset + custom", () => assert.equal(listAfterCustom.length, 17));

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
