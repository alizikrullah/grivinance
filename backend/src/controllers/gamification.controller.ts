import type { Request, Response } from "express";
import * as gamificationService from "../services/gamification.service";
import { ok } from "../utils/response.utils";

export async function state(req: Request, res: Response) {
  return ok(res, "Progres", await gamificationService.state(req.user!.id));
}

export async function claim(req: Request, res: Response) {
  const result = await gamificationService.claim(req.user!.id, String(req.params.key));
  return ok(res, "Misi diklaim", result);
}
