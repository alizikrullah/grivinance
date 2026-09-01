FROM node:20-slim

# Prisma masih ngecek versi libssl waktu generate. Tanpa ini muncul warning
# "failed to detect the libssl/openssl version" di tiap build.
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./

# --include=dev WAJIB. Coolify inject NODE_ENV=production waktu build, dan npm
# otomatis nge-skip devDependencies kalau variabel itu ada. Padahal typescript
# + @types/* dipakai `npm run build`, dan tsx dipakai runtime buat `prisma db seed`.
RUN npm ci --include=dev

COPY . .
RUN npx prisma generate && npm run build

EXPOSE 3000

# Tiga langkah muat di satu CMD, jadi tidak perlu entrypoint.sh — file .sh yang
# di-commit dari Windows kena CRLF dan mati dengan "exec format error".
# Seeder idempotent, jadi aman dijalankan tiap container start.
CMD ["sh", "-c", "npx prisma migrate deploy && npx prisma db seed && node dist/server.js"]
