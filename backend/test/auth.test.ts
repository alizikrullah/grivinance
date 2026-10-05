import "dotenv/config";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import app from "../src/app";
import { prisma } from "../src/prisma";
import { encryptPassword } from "../src/utils/password.utils";

const stamp = Date.now();
const email = `test.${stamp}@grivinance.local`;
const renamedEmail = `test.renamed.${stamp}@grivinance.local`;
// Akun Gmail: titik di nama akun sekarang dipertahankan, akun lama tersimpan tanpa titik.
const dottedGmail = `grivi.tes.${stamp}@gmail.com`;
const legacyGmail = `grivilama${stamp}@gmail.com`;
const password = "rahasia123";

const server = app.listen(0);
const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;

async function call(method: string, path: string, body?: unknown, token?: string) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: res.status, json: (await res.json()) as any };
}

/** Body mentah dengan Content-Type bebas — buat upload foto dan JSON rusak. */
async function raw(method: string, path: string, body: Uint8Array | string, type: string, token?: string) {
  return fetch(`${base}${path}`, {
    method,
    headers: { "Content-Type": type, ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body,
  });
}

/** Header PNG asli + sedikit isi. Server cuma memeriksa byte awalnya. */
const fakePng = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, 4, 5]);

async function main() {
  let passed = 0;
  const check = (label: string, fn: () => void) => {
    fn();
    console.log(`  ok  ${label}`);
    passed++;
  };

  const health = await call("GET", "/health");
  check("GET /health", () => assert.equal(health.json.status, "ok"));

  const bad = await call("POST", "/api/auth/register", { email: "x", password: "1", name: "" });
  check("register payload jelek -> 422", () => {
    assert.equal(bad.status, 422);
    assert.equal(bad.json.errors.length, 3);
  });

  const broken = await raw("POST", "/api/auth/login", "{bukan json", "application/json");
  check("body JSON rusak -> 400, bukan 500", () => assert.equal(broken.status, 400));

  const reg = await call("POST", "/api/auth/register", { email, password, name: "Test User" });
  check("register -> 201 + token", () => {
    assert.equal(reg.status, 201);
    assert.equal(reg.json.data.user.email, email);
    assert.ok(reg.json.data.accessToken);
    assert.ok(reg.json.data.refreshToken);
    assert.equal(reg.json.data.user.password, undefined);
  });

  const dup = await call("POST", "/api/auth/register", { email, password, name: "Test User" });
  check("register email dobel -> 409", () => assert.equal(dup.status, 409));

  const wrong = await call("POST", "/api/auth/login", { email, password: "salahbanget" });
  check("login password salah -> 401", () => assert.equal(wrong.status, 401));

  const login = await call("POST", "/api/auth/login", { email, password });
  check("login -> 200 + token", () => {
    assert.equal(login.status, 200);
    assert.ok(login.json.data.accessToken);
  });

  const { accessToken, refreshToken } = login.json.data;

  const me = await call("GET", "/api/auth/me", undefined, accessToken);
  check("GET /me pakai token -> 200", () => {
    assert.equal(me.status, 200);
    assert.equal(me.json.data.email, email);
    assert.equal(me.json.data.avatarUpdatedAt, null);
  });

  const noToken = await call("GET", "/api/auth/me");
  check("GET /me tanpa token -> 401", () => assert.equal(noToken.status, 401));

  // ---------- refresh: APK lama (tanpa rotasi) ----------
  const refreshed = await call("POST", "/api/auth/refresh", { refreshToken });
  check("refresh tanpa rotate -> access token saja (APK lama)", () => {
    assert.equal(refreshed.status, 200);
    assert.ok(refreshed.json.data.accessToken);
    assert.equal(refreshed.json.data.refreshToken, undefined);
  });

  const meAgain = await call("GET", "/api/auth/me", undefined, refreshed.json.data.accessToken);
  check("token hasil refresh kepake", () => assert.equal(meAgain.status, 200));

  // ---------- refresh: rotasi (REQ-7) ----------
  const rotated = await call("POST", "/api/auth/refresh", { refreshToken, rotate: true });
  check("refresh rotate -> refresh token baru", () => {
    assert.equal(rotated.status, 200);
    assert.ok(rotated.json.data.refreshToken);
    assert.notEqual(rotated.json.data.refreshToken, refreshToken);
  });

  const oldStored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
  check("token lama dipendekkan ke masa tenggang ±2 menit", () => {
    const left = oldStored!.expiresAt.getTime() - Date.now();
    assert.ok(left > 0 && left <= 2 * 60 * 1000);
  });

  const graceRetry = await call("POST", "/api/auth/refresh", { refreshToken, rotate: true });
  check("token lama masih diterima selama tenggang (respons hilang di jalan)", () =>
    assert.equal(graceRetry.status, 200),
  );

  const nextRefresh = rotated.json.data.refreshToken;
  const viaNew = await call("POST", "/api/auth/refresh", { refreshToken: nextRefresh });
  check("refresh token hasil rotasi kepake", () => assert.equal(viaNew.status, 200));

  const badRefresh = await call("POST", "/api/auth/refresh", { refreshToken: "ngarang" });
  check("refresh token ngarang -> 401", () => assert.equal(badRefresh.status, 401));

  const logout = await call("DELETE", "/api/auth/logout", { refreshToken: nextRefresh });
  check("logout -> 200", () => assert.equal(logout.status, 200));

  const afterLogout = await call("POST", "/api/auth/refresh", { refreshToken: nextRefresh });
  check("refresh sesudah logout -> 401", () => assert.equal(afterLogout.status, 401));

  // ---------- profil (REQ-6) ----------
  const token = accessToken;
  const profile = await call(
    "PUT",
    "/api/auth/me",
    { name: "Test Lengkap", nickname: "Tes", phone: "0812-3456 7890", birthDate: "1999-04-17" },
    token,
  );
  check("PUT /me simpan profil, nomor HP dirapikan", () => {
    assert.equal(profile.status, 200);
    assert.equal(profile.json.data.nickname, "Tes");
    assert.equal(profile.json.data.phone, "081234567890");
    assert.equal(profile.json.data.birthDate, "1999-04-17");
  });

  const cleared = await call("PUT", "/api/auth/me", { name: "Test Lengkap" }, token);
  check("PUT /me tanpa field opsional -> dikosongkan", () => {
    assert.equal(cleared.json.data.nickname, null);
    assert.equal(cleared.json.data.phone, null);
    assert.equal(cleared.json.data.birthDate, null);
  });

  const future = await call("PUT", "/api/auth/me", { name: "X", birthDate: "2999-01-01" }, token);
  const badPhone = await call("PUT", "/api/auth/me", { name: "X", phone: "12ab" }, token);
  check("tanggal lahir di masa depan / nomor HP ngawur -> 422", () => {
    assert.equal(future.status, 422);
    assert.equal(badPhone.status, 422);
  });

  // ---------- foto profil ----------
  const upload = await raw("PUT", "/api/auth/me/avatar", fakePng, "image/png", token);
  check("upload foto -> 200", () => assert.equal(upload.status, 200));

  const avatar = await fetch(`${base}/api/auth/me/avatar`, { headers: { Authorization: `Bearer ${token}` } });
  const avatarBytes = new Uint8Array(await avatar.arrayBuffer());
  check("GET foto -> byte dan tipe yang sama", () => {
    assert.equal(avatar.headers.get("content-type"), "image/png");
    assert.deepEqual(avatarBytes, fakePng);
  });

  const meWithAvatar = await call("GET", "/api/auth/me", undefined, token);
  check("/me bawa avatarUpdatedAt", () => assert.ok(meWithAvatar.json.data.avatarUpdatedAt));

  const notImage = await raw("PUT", "/api/auth/me/avatar", "bukan gambar", "image/png", token);
  const tooBig = await raw("PUT", "/api/auth/me/avatar", new Uint8Array(1024 * 1024 + 1), "image/jpeg", token);
  check("foto palsu -> 415, kebesaran -> 413", () => {
    assert.equal(notImage.status, 415);
    assert.equal(tooBig.status, 413);
  });

  await call("DELETE", "/api/auth/me/avatar", undefined, token);
  const afterDelete = await fetch(`${base}/api/auth/me/avatar`, { headers: { Authorization: `Bearer ${token}` } });
  check("hapus foto -> GET 404", () => assert.equal(afterDelete.status, 404));

  // ---------- ganti email & password ----------
  const wrongPass = await call("PUT", "/api/auth/me/email", { email: renamedEmail, currentPassword: "salah123" }, token);
  check("ganti email, password lama salah -> 422 (bukan 401)", () => assert.equal(wrongPass.status, 422));

  const renamed = await call("PUT", "/api/auth/me/email", { email: renamedEmail, currentPassword: password }, token);
  check("ganti email -> 200", () => assert.equal(renamed.json.data.email, renamedEmail));

  const sessionBefore = (await call("POST", "/api/auth/login", { email: renamedEmail, password })).json.data;
  const changed = await call(
    "PUT",
    "/api/auth/me/password",
    { currentPassword: password, newPassword: "rahasiabaru1" },
    sessionBefore.accessToken,
  );
  check("ganti password -> pasangan token baru", () => {
    assert.equal(changed.status, 200);
    assert.ok(changed.json.data.refreshToken);
  });

  const oldSession = await call("POST", "/api/auth/refresh", { refreshToken: sessionBefore.refreshToken });
  const newLogin = await call("POST", "/api/auth/login", { email: renamedEmail, password: "rahasiabaru1" });
  check("ganti password mematikan sesi lama, password baru kepake", () => {
    assert.equal(oldSession.status, 401);
    assert.equal(newLogin.status, 200);
  });

  // ---------- email Gmail ----------
  const gmail = await call("POST", "/api/auth/register", { email: dottedGmail, password, name: "Gmail" });
  check("titik di email Gmail dipertahankan", () => assert.equal(gmail.json.data.user.email, dottedGmail));

  await prisma.user.create({ data: { email: legacyGmail, name: "Lama", password: encryptPassword(password) } });
  const legacyDotted = legacyGmail.replace("grivilama", "grivi.lama");
  const legacyLogin = await call("POST", "/api/auth/login", { email: legacyDotted, password });
  const legacyDup = await call("POST", "/api/auth/register", { email: legacyDotted, password, name: "Dobel" });
  check("akun Gmail lama (tanpa titik) tetap bisa login dan nggak bisa didaftarkan dobel", () => {
    assert.equal(legacyLogin.status, 200);
    assert.equal(legacyDup.status, 409);
  });

  const categories = await prisma.category.count({ where: { userId: null } });
  check("seeder: 17 kategori preset", () => assert.equal(categories, 17));

  console.log(`\n${passed} check lolos`);
}

main()
  .catch((e) => {
    console.error("\nGAGAL:", e.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.user.deleteMany({
      where: { email: { in: [email, renamedEmail, dottedGmail, legacyGmail] } },
    });
    await prisma.$disconnect();
    server.close();
  });
