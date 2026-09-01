import "dotenv/config";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import app from "../src/app";
import { prisma } from "../src/prisma";

const email = `test.${Date.now()}@grivinance.local`;
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
  });

  const noToken = await call("GET", "/api/auth/me");
  check("GET /me tanpa token -> 401", () => assert.equal(noToken.status, 401));

  const refreshed = await call("POST", "/api/auth/refresh", { refreshToken });
  check("refresh -> access token baru", () => {
    assert.equal(refreshed.status, 200);
    assert.ok(refreshed.json.data.accessToken);
  });

  const meAgain = await call("GET", "/api/auth/me", undefined, refreshed.json.data.accessToken);
  check("token hasil refresh kepake", () => assert.equal(meAgain.status, 200));

  const badRefresh = await call("POST", "/api/auth/refresh", { refreshToken: "ngarang" });
  check("refresh token ngarang -> 401", () => assert.equal(badRefresh.status, 401));

  const logout = await call("DELETE", "/api/auth/logout", { refreshToken });
  check("logout -> 200", () => assert.equal(logout.status, 200));

  const afterLogout = await call("POST", "/api/auth/refresh", { refreshToken });
  check("refresh sesudah logout -> 401", () => assert.equal(afterLogout.status, 401));

  const categories = await prisma.category.count({ where: { userId: null } });
  check("seeder: 16 kategori preset", () => assert.equal(categories, 16));

  console.log(`\n${passed} check lolos`);
}

main()
  .catch((e) => {
    console.error("\nGAGAL:", e.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    server.close();
  });
