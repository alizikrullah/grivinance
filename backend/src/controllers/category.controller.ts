import type { Request, Response } from "express";
import { matchedData } from "express-validator";
import * as categoryService from "../services/category.service";
import { ok } from "../utils/response.utils";

// matchedData, bukan req.body: body mentah bisa menyelundupkan `userId: null`
// dan menjadikan kategori custom preset global untuk semua user (BUG-3).
const input = (req: Request) =>
  matchedData(req, { locations: ["body"] }) as categoryService.CategoryInput;

export async function list(req: Request, res: Response) {
  return ok(res, "Daftar kategori", await categoryService.list(req.user!.id));
}

export async function create(req: Request, res: Response) {
  return ok(res, "Kategori ditambahkan", await categoryService.create(req.user!.id, input(req)), 201);
}

export async function update(req: Request, res: Response) {
  return ok(res, "Kategori diperbarui", await categoryService.update(req.user!.id, String(req.params.id), input(req)));
}

export async function remove(req: Request, res: Response) {
  await categoryService.remove(req.user!.id, String(req.params.id));
  return ok(res, "Kategori dihapus");
}
