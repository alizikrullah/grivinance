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

type WalletRow = {
  balance: unknown;
  _count?: { transactions: number; transfersIn: number };
} & Record<string, unknown>;

/**
 * transactionCount ikut dikirim supaya Flutter tahu boleh menampilkan field
 * saldo awal atau tidak, tanpa perlu query transaksi terpisah cuma buat
 * menghitung. Transfer masuk ikut dihitung: dia juga mengubah saldo.
 */
function toDto(wallet: WalletRow) {
  const { _count, ...rest } = wallet;
  return {
    ...rest,
    balance: money(wallet.balance as string),
    transactionCount: (_count?.transactions ?? 0) + (_count?.transfersIn ?? 0),
  };
}

const withCount = { _count: { select: { transactions: true, transfersIn: true } } } as const;

/** Semua baris yang mengubah saldo wallet ini: miliknya sendiri + transfer yang masuk. */
const touching = (id: string) => ({ OR: [{ walletId: id }, { toWalletId: id }] });

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
    data: {
      name: input.name,
      type: input.type,
      icon: input.icon,
      color: input.color,
      balance: input.balance ?? "0",
      userId,
    },
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
    const used = await prisma.transaction.count({ where: touching(id) });
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

  // Menghapus wallet ikut menghapus transaksinya (Cascade). Untuk transfer itu
  // berarti saldo wallet di seberangnya berubah tanpa catatan yang
  // menjelaskannya — jadi ditolak, transfernya harus dihapus dulu.
  const transfers = await prisma.transaction.count({
    where: { type: "transfer", ...touching(id) },
  });
  if (transfers > 0) {
    throw new AppError(
      409,
      `Wallet ini terlibat di ${transfers} transfer. Hapus transfernya dulu supaya saldo wallet lain tetap benar`,
    );
  }

  await prisma.wallet.delete({ where: { id } });
}
