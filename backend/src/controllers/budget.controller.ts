import type { Request, Response } from "express";
import * as budgetService from "../services/budget.service";
import { ok } from "../utils/response.utils";

export async function list(req: Request, res: Response) {
  const { year, month } = req.query;
  return ok(res, "Daftar budget", await budgetService.list(req.user!.id, Number(year), Number(month)));
}

export async function set(req: Request, res: Response) {
  const result = await budgetService.set(req.user!.id, String(req.params.categoryId), req.body.amount);
  return ok(res, "Budget disimpan", result);
}

export async function remove(req: Request, res: Response) {
  await budgetService.remove(req.user!.id, String(req.params.categoryId));
  return ok(res, "Budget dihapus");
}
