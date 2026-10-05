import type { Request, Response } from "express";
import { matchedData } from "express-validator";
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
  const result = await authService.refresh(req.body.refreshToken, req.body.rotate === true);
  return ok(res, "Token diperbarui", result);
}

export async function me(req: Request, res: Response) {
  return ok(res, "Profil user", await authService.me(req.user!.id));
}

export async function logout(req: Request, res: Response) {
  await authService.logout(req.body.refreshToken);
  return ok(res, "Logout berhasil");
}

export async function updateProfile(req: Request, res: Response) {
  const input = matchedData(req, { locations: ["body"] }) as authService.ProfileInput;
  return ok(res, "Profil diperbarui", await authService.updateProfile(req.user!.id, input));
}

export async function changeEmail(req: Request, res: Response) {
  const { email, currentPassword } = req.body;
  return ok(res, "Email diperbarui", await authService.changeEmail(req.user!.id, email, currentPassword));
}

export async function changePassword(req: Request, res: Response) {
  const { currentPassword, newPassword } = req.body;
  const tokens = await authService.changePassword(req.user!.id, currentPassword, newPassword);
  return ok(res, "Password diperbarui", tokens);
}

export async function avatar(req: Request, res: Response) {
  const { data, mimeType } = await authService.getAvatar(req.user!.id);
  res.set("Content-Type", mimeType).set("Cache-Control", "private, no-cache");
  return res.send(Buffer.from(data));
}

export async function setAvatar(req: Request, res: Response) {
  return ok(res, "Foto profil diperbarui", await authService.setAvatar(req.user!.id, req.body));
}

export async function deleteAvatar(req: Request, res: Response) {
  await authService.deleteAvatar(req.user!.id);
  return ok(res, "Foto profil dihapus");
}
