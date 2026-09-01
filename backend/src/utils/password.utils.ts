import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";

// Password disimpan terenkripsi dua arah (AES-256-GCM), bukan di-hash.
// Artinya: siapa pun yang pegang DB + PASSWORD_SECRET bisa baca semua password user.
// PASSWORD_SECRET wajib diperlakukan sebagai rahasia paling sensitif di sistem ini.
const secret = process.env.PASSWORD_SECRET;
if (!secret) throw new Error("ENV PASSWORD_SECRET belum di-set");

const key = scryptSync(secret, "grivinance-password", 32);

export function encryptPassword(plain: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const body = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  return [iv, cipher.getAuthTag(), body].map((b) => b.toString("base64url")).join(".");
}

export function decryptPassword(stored: string): string {
  const [iv, tag, body] = stored.split(".").map((part) => Buffer.from(part, "base64url"));
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(body), decipher.final()]).toString("utf8");
}

export function verifyPassword(plain: string, stored: string): boolean {
  try {
    const actual = Buffer.from(decryptPassword(stored), "utf8");
    const given = Buffer.from(plain, "utf8");
    return actual.length === given.length && timingSafeEqual(actual, given);
  } catch {
    return false;
  }
}
