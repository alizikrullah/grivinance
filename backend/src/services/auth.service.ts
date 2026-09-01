import { prisma } from "../prisma";
import { encryptPassword, verifyPassword } from "../utils/password.utils";
import { AppError } from "../utils/response.utils";
import {
  refreshTokenExpiry,
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from "../utils/jwt.utils";

const publicUser = { id: true, email: true, name: true, createdAt: true } as const;

async function issueTokens(userId: string) {
  const accessToken = signAccessToken(userId);
  const refreshToken = signRefreshToken(userId);

  await prisma.refreshToken.create({
    data: { userId, token: refreshToken, expiresAt: refreshTokenExpiry(refreshToken) },
  });

  return { accessToken, refreshToken };
}

export async function register(email: string, password: string, name: string) {
  const exists = await prisma.user.findUnique({ where: { email } });
  if (exists) throw new AppError(409, "Email sudah terdaftar");

  const user = await prisma.user.create({
    data: { email, name, password: encryptPassword(password) },
    select: publicUser,
  });

  return { user, ...(await issueTokens(user.id)) };
}

export async function login(email: string, password: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !verifyPassword(password, user.password)) {
    throw new AppError(401, "Email atau password salah");
  }

  const { password: _stored, updatedAt, ...safe } = user;
  return { user: safe, ...(await issueTokens(user.id)) };
}

export async function refresh(token: string) {
  const stored = await prisma.refreshToken.findUnique({ where: { token } });
  if (!stored) throw new AppError(401, "Refresh token tidak valid");

  if (stored.expiresAt < new Date()) {
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    throw new AppError(401, "Refresh token sudah kedaluwarsa");
  }

  try {
    verifyRefreshToken(token);
  } catch {
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    throw new AppError(401, "Refresh token tidak valid");
  }

  return { accessToken: signAccessToken(stored.userId) };
}

export async function logout(token: string) {
  await prisma.refreshToken.deleteMany({ where: { token } });
}

export async function me(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: publicUser });
  if (!user) throw new AppError(404, "User tidak ditemukan");
  return user;
}
