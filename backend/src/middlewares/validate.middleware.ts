import type { NextFunction, Request, Response } from "express";
import { validationResult } from "express-validator";
import { fail } from "../utils/response.utils";

export function validate(req: Request, res: Response, next: NextFunction) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return next();
  return fail(res, 422, "Validasi gagal", errors.array());
}
