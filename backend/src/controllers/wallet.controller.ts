import type { Request, Response } from "express";
import * as walletService from "../services/wallet.service";
import { ok } from "../utils/response.utils";

export async function list(req: Request, res: Response) {
  return ok(res, "Daftar wallet", await walletService.list(req.user!.id));
}

export async function create(req: Request, res: Response) {
  return ok(res, "Wallet ditambahkan", await walletService.create(req.user!.id, req.body), 201);
}

export async function update(req: Request, res: Response) {
  return ok(res, "Wallet diperbarui", await walletService.update(req.user!.id, String(req.params.id), req.body));
}

export async function remove(req: Request, res: Response) {
  await walletService.remove(req.user!.id, String(req.params.id));
  return ok(res, "Wallet dihapus beserta seluruh transaksinya");
}
