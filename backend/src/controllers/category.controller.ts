import type { Request, Response } from "express";
import * as categoryService from "../services/category.service";
import { ok } from "../utils/response.utils";

export async function list(req: Request, res: Response) {
  return ok(res, "Daftar kategori", await categoryService.list(req.user!.id));
}

export async function create(req: Request, res: Response) {
  return ok(res, "Kategori ditambahkan", await categoryService.create(req.user!.id, req.body), 201);
}

export async function update(req: Request, res: Response) {
  return ok(res, "Kategori diperbarui", await categoryService.update(req.user!.id, String(req.params.id), req.body));
}

export async function remove(req: Request, res: Response) {
  await categoryService.remove(req.user!.id, String(req.params.id));
  return ok(res, "Kategori dihapus");
}
