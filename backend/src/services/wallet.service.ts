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

type WalletRow = { balance: unknown } & Record<string, unknown>;

const toDto = (wallet: WalletRow) => ({ ...wallet, balance: money(wallet.balance as string) });

async function ownedWallet(userId: string, id: string) {
  const wallet = await prisma.wallet.findFirst({ where: { id, userId } });
  if (!wallet) throw new AppError(404, "Wallet tidak ditemukan");
  return wallet;
}

export async function list(userId: string) {
  const wallets = await prisma.wallet.findMany({
    where: { userId },
    orderBy: { createdAt: "asc" },
  });
  return wallets.map(toDto);
}

export async function create(userId: string, input: WalletInput) {
  const wallet = await prisma.wallet.create({
    data: { ...input, balance: input.balance ?? "0", userId },
  });
  return toDto(wallet);
}

export async function update(userId: string, id: string, input: Partial<WalletInput>) {
  await ownedWallet(userId, id);
  const wallet = await prisma.wallet.update({ where: { id }, data: input });
  return toDto(wallet);
}

export async function remove(userId: string, id: string) {
  await ownedWallet(userId, id);
  // Transaction.wallet pakai onDelete: Cascade, jadi transaksinya ikut kehapus.
  await prisma.wallet.delete({ where: { id } });
}
