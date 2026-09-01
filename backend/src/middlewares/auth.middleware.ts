import type { NextFunction, Request, Response } from "express";
import { verifyAccessToken } from "../utils/jwt.utils";
import { fail } from "../utils/response.utils";

declare global {
  namespace Express {
    interface Request {
      user?: { id: string };
    }
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return fail(res, 401, "Token tidak ada");
  }

  try {
    req.user = { id: verifyAccessToken(header.slice(7)).sub };
    next();
  } catch {
    return fail(res, 401, "Token tidak valid atau kedaluwarsa");
  }
}
