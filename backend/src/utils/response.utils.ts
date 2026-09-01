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
