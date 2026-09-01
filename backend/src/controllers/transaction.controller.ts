import type { Request, Response } from "express";
import * as transactionService from "../services/transaction.service";
import { ok } from "../utils/response.utils";

export async function list(req: Request, res: Response) {
  const { page, limit, walletId, categoryId, type, startDate, endDate } = req.query;
  const result = await transactionService.list(req.user!.id, {
    page: page ? Number(page) : undefined,
    limit: limit ? Number(limit) : undefined,
    walletId: walletId as string | undefined,
    categoryId: categoryId as string | undefined,
    type: type as "income" | "expense" | undefined,
    startDate: startDate as string | undefined,
    endDate: endDate as string | undefined,
  });
  return ok(res, "Daftar transaksi", result);
}

export async function detail(req: Request, res: Response) {
  return ok(res, "Detail transaksi", await transactionService.detail(req.user!.id, String(req.params.id)));
}

export async function create(req: Request, res: Response) {
  return ok(res, "Transaksi ditambahkan", await transactionService.create(req.user!.id, req.body), 201);
}

export async function update(req: Request, res: Response) {
  return ok(res, "Transaksi diperbarui", await transactionService.update(req.user!.id, String(req.params.id), req.body));
}

export async function remove(req: Request, res: Response) {
  await transactionService.remove(req.user!.id, String(req.params.id));
  return ok(res, "Transaksi dihapus");
}
