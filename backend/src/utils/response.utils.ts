import { Prisma } from "../generated/prisma/client";
import type { Response } from "express";

/** Error yang sengaja dilempar service dengan status HTTP-nya. */
export class AppError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function ok(res: Response, message: string, data: unknown = null, status = 200) {
  return res.status(status).json({ success: true, message, data });
}

export function fail(res: Response, status: number, message: string, errors: unknown[] = []) {
  return res.status(status).json({ success: false, message, errors });
}

/**
 * Uang selalu lewat kabel sebagai string dua desimal.
 * Decimal.js buang nol di belakang kalau pakai toString(), jadi wajib toFixed(2).
 */
export function money(value: Prisma.Decimal | number | string): string {
  return new Prisma.Decimal(value).toFixed(2);
}
