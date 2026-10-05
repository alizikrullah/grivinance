import { Router } from "express";
import { body, query } from "express-validator";
import * as transactionController from "../controllers/transaction.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { calendarDateRule, moneyRule, validate } from "../middlewares/validate.middleware";

const router = Router();
router.use(requireAuth);

const isTransfer = body("type").equals("transfer");
const isNotTransfer = body("type").not().equals("transfer");

const rules = [
  body("type").isIn(["income", "expense", "transfer"]).withMessage("Tipe transaksi tidak valid"),
  body("walletId").isString().notEmpty().withMessage("Wallet wajib dipilih"),
  body("categoryId").if(isNotTransfer).isString().notEmpty().withMessage("Kategori wajib dipilih"),
  body("toWalletId").if(isTransfer).isString().notEmpty().withMessage("Wallet tujuan wajib dipilih"),
  moneyRule(body("amount"), "Jumlah", { positive: true }),
  moneyRule(body("fee").if(isTransfer).optional({ values: "falsy" }), "Biaya admin"),
  // Tanpa offset tetap diterima dan dibaca sebagai WIB — lihat parseClientDate.
  body("date").isISO8601().withMessage("Tanggal tidak valid"),
  body("note").optional({ values: "null" }).isString().isLength({ max: 500 }),
];

const filters = [
  query("page").optional().isInt({ min: 1 }).withMessage("Page minimal 1"),
  query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("Limit 1-100"),
  query("type").optional().isIn(["income", "expense", "transfer"]),
  calendarDateRule(query("startDate").optional(), "startDate"),
  calendarDateRule(query("endDate").optional(), "endDate"),
];

router.get("/", filters, validate, transactionController.list);
router.get("/:id", transactionController.detail);
router.post("/", rules, validate, transactionController.create);
router.put("/:id", rules, validate, transactionController.update);
router.delete("/:id", transactionController.remove);

export default router;
