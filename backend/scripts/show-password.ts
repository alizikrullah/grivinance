import "dotenv/config";
import { prisma } from "../src/prisma";
import { decryptPassword } from "../src/utils/password.utils";

const email = process.argv[2];

if (!email) {
  console.error("Pakai: npm run password -- <email>");
  process.exit(1);
}

prisma.user
  .findUnique({ where: { email }, select: { email: true, name: true, password: true } })
  .then((user) => {
    if (!user) throw new Error(`User ${email} tidak ada`);
    console.log(`${user.name} <${user.email}>`);
    console.log(`password: ${decryptPassword(user.password)}`);
  })
  .catch((e) => {
    console.error(e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
