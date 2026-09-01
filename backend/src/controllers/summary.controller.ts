import type { Request, Response } from "express";
import * as summaryService from "../services/summary.service";
import { ok } from "../utils/response.utils";

export async function daily(req: Request, res: Response) {
  return ok(res, "Ringkasan harian", await summaryService.daily(req.user!.id, req.query.date as string));
}

export async function monthly(req: Request, res: Response) {
  const { year, month } = req.query;
  return ok(res, "Ringkasan bulanan", await summaryService.monthly(req.user!.id, Number(year), Number(month)));
}

export async function yearly(req: Request, res: Response) {
  return ok(res, "Ringkasan tahunan", await summaryService.yearly(req.user!.id, Number(req.query.year)));
}
