import express, { type NextFunction, type Request, type Response } from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import authRoutes from "./routes/auth.routes";
import walletRoutes from "./routes/wallet.routes";
import categoryRoutes from "./routes/category.routes";
import transactionRoutes from "./routes/transaction.routes";
import summaryRoutes from "./routes/summary.routes";
import { AppError, fail } from "./utils/response.utils";

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan("tiny"));

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/auth", authRoutes);
app.use("/api/wallets", walletRoutes);
app.use("/api/categories", categoryRoutes);
app.use("/api/transactions", transactionRoutes);
app.use("/api/summary", summaryRoutes);

app.use((_req: Request, res: Response) => fail(res, 404, "Endpoint tidak ditemukan"));

// Express 5 meneruskan error dari async handler ke sini otomatis.
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof AppError) return fail(res, err.status, err.message);

  console.error(err);
  return fail(res, 500, "Terjadi kesalahan di server");
});

export default app;
