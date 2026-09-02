import { prisma } from "../prisma";
import { AppError, money } from "../utils/response.utils";
import type { WalletType } from "../generated/prisma/enums";

export type WalletInput = {
  name: string;
  type: WalletType;
  balance?: string;
  icon: string;
  color: string;
};

type WalletRow = { balance: unknown; _count?: { transactions: number } } & Record<
  string,
  unknown
>;

/**
 * transactionCount ikut dikirim supaya Flutter tahu boleh menampilkan field
 * saldo awal atau tidak, tanpa perlu query transaksi terpisah cuma buat
 * menghitung.
 */
function toDto(wallet: WalletRow) {
  const { _count, ...rest } = wallet;
  return {
    ...rest,
    balance: money(wallet.balance as string),
    transactionCount: _count?.transactions ?? 0,
  };
}

const withCount = { _count: { select: { transactions: true } } } as const;

async function ownedWallet(userId: string, id: string) {
  const wallet = await prisma.wallet.findFirst({ where: { id, userId } });
  if (!wallet) throw new AppError(404, "Wallet tidak ditemukan");
  return wallet;
}

export async function list(userId: string) {
  const wallets = await prisma.wallet.findMany({
    where: { userId },
    orderBy: { createdAt: "asc" },
    include: withCount,
  });
  return wallets.map(toDto);
}

export async function create(userId: string, input: WalletInput) {
  const wallet = await prisma.wallet.create({
    data: { ...input, balance: input.balance ?? "0", userId },
    include: withCount,
  });
  return toDto(wallet);
}

export async function update(userId: string, id: string, input: Partial<WalletInput>) {
  await ownedWallet(userId, id);

  // Saldo awal cuma boleh diubah selama wallet belum punya transaksi. Setelah
  // ada transaksi, balance = saldo awal + jumlah semua transaksi, dan dua
  // komponen itu tidak disimpan terpisah — menimpanya bikin angkanya tidak bisa
  // dipertanggungjawabkan. Dijaga di sini, bukan cuma disembunyikan di UI:
  // kalau hanya klien yang menahan, panggilan API langsung bisa merusak saldo.
  if (input.balance !== undefined) {
    const used = await prisma.transaction.count({ where: { walletId: id } });
    if (used > 0) {
      throw new AppError(
        409,
        `Wallet sudah punya ${used} transaksi, saldo awal tidak bisa diubah`,
      );
    }
  }

  const wallet = await prisma.wallet.update({
    where: { id },
    data: input,
    include: withCount,
  });
  return toDto(wallet);
}

export async function remove(userId: string, id: string) {
  await ownedWallet(userId, id);
  // Transaction.wallet pakai onDelete: Cascade, jadi transaksinya ikut kehapus.
  await prisma.wallet.delete({ where: { id } });
}
