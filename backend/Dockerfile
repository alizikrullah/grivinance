FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npx prisma generate && npm run build

EXPOSE 3000

# Tiga langkah muat di satu CMD, jadi tidak perlu entrypoint.sh — file .sh yang
# di-commit dari Windows kena CRLF dan mati dengan "exec format error".
# Seeder idempotent, jadi aman dijalankan tiap container start.
CMD ["sh", "-c", "npx prisma migrate deploy && npx prisma db seed && node dist/server.js"]
