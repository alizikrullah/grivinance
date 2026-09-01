import type { Request, Response } from "express";
import * as authService from "../services/auth.service";
import { ok } from "../utils/response.utils";

export async function register(req: Request, res: Response) {
  const { email, password, name } = req.body;
  const result = await authService.register(email, password, name);
  return ok(res, "Registrasi berhasil", result, 201);
}

export async function login(req: Request, res: Response) {
  const { email, password } = req.body;
  return ok(res, "Login berhasil", await authService.login(email, password));
}

export async function refresh(req: Request, res: Response) {
  return ok(res, "Token diperbarui", await authService.refresh(req.body.refreshToken));
}

export async function me(req: Request, res: Response) {
  return ok(res, "Profil user", await authService.me(req.user!.id));
}

export async function logout(req: Request, res: Response) {
  await authService.logout(req.body.refreshToken);
  return ok(res, "Logout berhasil");
}
