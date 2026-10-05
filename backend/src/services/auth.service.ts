import { prisma } from "../prisma";
import { encryptPassword, verifyPassword } from "../utils/password.utils";
import { AppError } from "../utils/response.utils";
import {
  refreshTokenExpiry,
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from "../utils/jwt.utils";

/**
 * Token lama yang baru dirotasi masih diterima sebentar. Di jaringan HP,
 * respons refresh bisa hilang di jalan: server udah ganti token tapi HP masih
 * pegang yang lama. Tanpa tenggang, percobaan berikutnya ditolak dan user
 * ke-logout — persis logout acak yang mau dihindari.
 */
const ROTATION_GRACE_MS = 2 * 60 * 1000;

const profileSelect = {
  id: true,
  email: true,
  name: true,
  nickname: true,
  phone: true,
  birthDate: true,
  createdAt: true,
  avatar: { select: { updatedAt: true } },
} as const;

export type ProfileInput = {
  name: string;
  nickname?: string;
  phone?: string;
  birthDate?: string;
};

async function profile(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: profileSelect });
  if (!user) throw new AppError(404, "User tidak ditemukan");

  const { avatar, birthDate, ...rest } = user;
  return {
    ...rest,
    // Kolom DATE dikembalikan Prisma sebagai tengah malam UTC; kirim tanggalnya saja.
    birthDate: birthDate ? birthDate.toISOString().slice(0, 10) : null,
    avatarUpdatedAt: avatar?.updatedAt ?? null,
  };
}

/**
 * Gmail mengabaikan titik di nama akun. Dulu email dinormalisasi dengan titik
 * dibuang, sekarang titiknya dipertahankan — jadi akun lama tersimpan tanpa
 * titik. Cari dua bentuk supaya akun lama tetap bisa login dan nggak bisa
 * didaftarkan dobel.
 */
function emailVariants(email: string): string[] {
  const [local, domain] = email.split("@");
  if (domain !== "gmail.com" || !local) return [email];
  return [...new Set([email, `${local.replace(/\./g, "")}@${domain}`])];
}

function findByEmail(email: string) {
  return prisma.user.findFirst({ where: { email: { in: emailVariants(email) } } });
}

async function issueTokens(userId: string) {
  const accessToken = signAccessToken(userId);
  const refreshToken = signRefreshToken(userId);

  await prisma.$transaction([
    // Token kedaluwarsa nggak pernah dipakai lagi; bersihkan sekalian.
    prisma.refreshToken.deleteMany({ where: { userId, expiresAt: { lt: new Date() } } }),
    prisma.refreshToken.create({
      data: { userId, token: refreshToken, expiresAt: refreshTokenExpiry(refreshToken) },
    }),
  ]);

  return { accessToken, refreshToken };
}

export async function register(email: string, password: string, name: string) {
  if (await findByEmail(email)) throw new AppError(409, "Email sudah terdaftar");

  const user = await prisma.user.create({
    data: { email, name, password: encryptPassword(password) },
    select: { id: true },
  });

  return { user: await profile(user.id), ...(await issueTokens(user.id)) };
}

export async function login(email: string, password: string) {
  const user = await findByEmail(email);
  if (!user || !verifyPassword(password, user.password)) {
    throw new AppError(401, "Email atau password salah");
  }

  return { user: await profile(user.id), ...(await issueTokens(user.id)) };
}

/**
 * `rotate`: APK baru minta refresh token pengganti, jadi sesi terus geser
 * selama app dipakai (REQ-7). APK lama nggak kirim flag ini dan cuma dapat
 * access token seperti dulu — kalau dirotasi paksa, APK lama yang nggak
 * menyimpan token baru bakal ke-logout begitu masa tenggangnya habis.
 */
export async function refresh(token: string, rotate: boolean) {
  const stored = await prisma.refreshToken.findUnique({ where: { token } });
  if (!stored) throw new AppError(401, "Refresh token tidak valid");

  if (stored.expiresAt < new Date()) {
    await prisma.refreshToken.deleteMany({ where: { id: stored.id } });
    throw new AppError(401, "Refresh token sudah kedaluwarsa");
  }

  try {
    verifyRefreshToken(token);
  } catch {
    await prisma.refreshToken.deleteMany({ where: { id: stored.id } });
    throw new AppError(401, "Refresh token tidak valid");
  }

  if (!rotate) return { accessToken: signAccessToken(stored.userId) };

  const next = await issueTokens(stored.userId);
  const graceEnd = new Date(Date.now() + ROTATION_GRACE_MS);
  if (stored.expiresAt > graceEnd) {
    await prisma.refreshToken.updateMany({
      where: { id: stored.id },
      data: { expiresAt: graceEnd },
    });
  }
  return next;
}

export async function logout(token: string) {
  await prisma.refreshToken.deleteMany({ where: { token } });
}

export function me(userId: string) {
  return profile(userId);
}

export async function updateProfile(userId: string, input: ProfileInput) {
  // PUT = ganti seluruh profil: field opsional yang nggak dikirim berarti dikosongkan.
  await prisma.user.update({
    where: { id: userId },
    data: {
      name: input.name,
      nickname: input.nickname || null,
      phone: input.phone || null,
      birthDate: input.birthDate ? new Date(`${input.birthDate}T00:00:00.000Z`) : null,
    },
  });
  return profile(userId);
}

/** 422, bukan 401: 401 bikin klien mengira access token-nya kedaluwarsa dan mencoba refresh. */
async function assertPassword(userId: string, currentPassword: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError(404, "User tidak ditemukan");
  if (!verifyPassword(currentPassword, user.password)) {
    throw new AppError(422, "Password lama salah");
  }
}

export async function changeEmail(userId: string, email: string, currentPassword: string) {
  await assertPassword(userId, currentPassword);

  const owner = await findByEmail(email);
  if (owner && owner.id !== userId) throw new AppError(409, "Email sudah dipakai akun lain");

  await prisma.user.update({ where: { id: userId }, data: { email } });
  return profile(userId);
}

/**
 * Semua sesi lain ikut dimatikan — kalau password diganti karena dicurigai
 * bocor, sesi lama memang harus berhenti. HP yang sedang dipakai dapat
 * pasangan token baru supaya tetap masuk.
 */
export async function changePassword(userId: string, currentPassword: string, newPassword: string) {
  await assertPassword(userId, currentPassword);

  await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: { password: encryptPassword(newPassword) },
    }),
    prisma.refreshToken.deleteMany({ where: { userId } }),
  ]);

  return issueTokens(userId);
}

/** Jenis gambar dari byte awalnya, bukan dari header yang bisa diisi apa saja. */
function imageTypeOf(data: Buffer): string | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) {
    return "image/jpeg";
  }
  if (data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return "image/png";
  }
  if (
    data.subarray(0, 4).toString("latin1") === "RIFF" &&
    data.subarray(8, 12).toString("latin1") === "WEBP"
  ) {
    return "image/webp";
  }
  return null;
}

export async function setAvatar(userId: string, body: unknown) {
  if (!Buffer.isBuffer(body) || body.length === 0) {
    throw new AppError(415, "Kirim gambar JPEG, PNG, atau WebP");
  }

  const mimeType = imageTypeOf(body);
  if (!mimeType) throw new AppError(415, "File bukan gambar JPEG, PNG, atau WebP");

  // Prisma 7 minta Uint8Array di atas ArrayBuffer biasa; Buffer dari body-parser
  // bisa menumpang di buffer bersama. Salinan maksimal 1 MB, murah.
  const data = new Uint8Array(body);
  const avatar = await prisma.userAvatar.upsert({
    where: { userId },
    create: { userId, data, mimeType },
    update: { data, mimeType },
  });
  return { avatarUpdatedAt: avatar.updatedAt };
}

export async function getAvatar(userId: string) {
  const avatar = await prisma.userAvatar.findUnique({ where: { userId } });
  if (!avatar) throw new AppError(404, "Belum ada foto profil");
  return avatar;
}

export async function deleteAvatar(userId: string) {
  await prisma.userAvatar.deleteMany({ where: { userId } });
}
