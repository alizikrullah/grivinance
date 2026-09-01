import { randomUUID } from "node:crypto";
import jwt, { type SignOptions } from "jsonwebtoken";

function required(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`ENV ${key} belum di-set`);
  return value;
}

const ACCESS_SECRET = required("JWT_ACCESS_SECRET");
const REFRESH_SECRET = required("JWT_REFRESH_SECRET");
const ACCESS_EXPIRES = (process.env.JWT_ACCESS_EXPIRES_IN ?? "15m") as SignOptions["expiresIn"];
const REFRESH_EXPIRES = (process.env.JWT_REFRESH_EXPIRES_IN ?? "7d") as SignOptions["expiresIn"];

export type TokenPayload = { sub: string };

export function signAccessToken(userId: string): string {
  return jwt.sign({ sub: userId }, ACCESS_SECRET, { expiresIn: ACCESS_EXPIRES });
}

// jti bikin tiap refresh token unik. Tanpa ini dua login di detik yang sama
// menghasilkan JWT identik (iat cuma presisi detik) dan nabrak kolom token @unique.
export function signRefreshToken(userId: string): string {
  return jwt.sign({ sub: userId, jti: randomUUID() }, REFRESH_SECRET, {
    expiresIn: REFRESH_EXPIRES,
  });
}

export function verifyAccessToken(token: string): TokenPayload {
  return jwt.verify(token, ACCESS_SECRET) as TokenPayload;
}

export function verifyRefreshToken(token: string): TokenPayload {
  return jwt.verify(token, REFRESH_SECRET) as TokenPayload;
}

/** Tanggal kedaluwarsa refresh token, buat disimpan di kolom expires_at. */
export function refreshTokenExpiry(token: string): Date {
  const { exp } = jwt.decode(token) as { exp: number };
  return new Date(exp * 1000);
}
