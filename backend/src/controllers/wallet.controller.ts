import type { Request, Response } from "express";
import { matchedData } from "express-validator";
import * as walletService from "../services/wallet.service";
import { ok } from "../utils/response.utils";

// matchedData, bukan req.body: cuma field yang lolos validasi yang diteruskan
// ke Prisma. Body mentah bisa menyelundupkan `userId` dan memindahkan wallet
// ke akun lain (BUG-3).
const input = (req: Request) =>
  matchedData(req, { locations: ["body"] }) as walletService.WalletInput;

export async function list(req: Request, res: Response) {
  return ok(res, "Daftar wallet", await walletService.list(req.user!.id));
}

export async function create(req: Request, res: Response) {
  return ok(res, "Wallet ditambahkan", await walletService.create(req.user!.id, input(req)), 201);
}

export async function update(req: Request, res: Response) {
  return ok(res, "Wallet diperbarui", await walletService.update(req.user!.id, String(req.params.id), input(req)));
}

export async function remove(req: Request, res: Response) {
  await walletService.remove(req.user!.id, String(req.params.id));
  return ok(res, "Wallet dihapus beserta seluruh transaksinya");
}
