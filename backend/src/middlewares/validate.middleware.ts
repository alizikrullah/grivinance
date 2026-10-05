import type { NextFunction, Request, Response } from "express";
import { validationResult, type ValidationChain } from "express-validator";
import { isCalendarDate } from "../utils/date.utils";
import { fail } from "../utils/response.utils";

export function validate(req: Request, res: Response, next: NextFunction) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return next();
  return fail(res, 422, "Validasi gagal", errors.array());
}

/** Di bawah batas kolom Decimal(15,2), dengan sisa ruang buat saldo yang menjumlah. */
const MAX_AMOUNT = 999_999_999_999;

/**
 * Nominal uang dari klien: maksimal 2 desimal dan di dalam batas kolom.
 * Tanpa batas atas, angka kebesaran lolos validasi lalu ditolak Postgres → 500.
 */
export function moneyRule(
  chain: ValidationChain,
  label: string,
  { positive = false, signed = false } = {},
) {
  return chain
    .isDecimal({ decimal_digits: "0,2" })
    .withMessage(`${label} harus angka maksimal 2 desimal`)
    .bail()
    .custom((value: string) => {
      const n = Number(value);
      if (positive && n <= 0) return false;
      if (!signed && n < 0) return false;
      return Math.abs(n) <= MAX_AMOUNT;
    })
    .withMessage(
      positive
        ? `${label} harus lebih dari 0 dan maksimal 999 miliar`
        : `${label} di luar batas yang diizinkan`,
    );
}

/** "YYYY-MM-DD" yang beneran ada di kalender. */
export function calendarDateRule(chain: ValidationChain, label: string) {
  return chain.custom(isCalendarDate).withMessage(`${label} harus tanggal valid berformat YYYY-MM-DD`);
}
