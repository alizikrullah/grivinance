import { Router } from "express";
import { body, query } from "express-validator";
import * as transactionController from "../controllers/transaction.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { validate } from "../middlewares/validate.middleware";

const router = Router();
router.use(requireAuth);

const rules = [
  body("walletId").isString().notEmpty().withMessage("Wallet wajib dipilih"),
  body("categoryId").isString().notEmpty().withMessage("Kategori wajib dipilih"),
  body("type").isIn(["income", "expense"]).withMessage("Tipe transaksi tidak valid"),
  body("amount")
    .isDecimal({ decimal_digits: "0,2" })
    .withMessage("Jumlah harus angka maksimal 2 desimal")
    .bail()
    .custom((value: string) => Number(value) > 0)
    .withMessage("Jumlah harus lebih dari 0"),
  body("date").isISO8601().withMessage("Tanggal tidak valid"),
  body("note").optional({ values: "null" }).isString(),
];

const filters = [
  query("page").optional().isInt({ min: 1 }).withMessage("Page minimal 1"),
  query("limit").optional().isInt({ min: 1, max: 100 }).withMessage("Limit 1-100"),
  query("type").optional().isIn(["income", "expense"]),
  query("startDate").optional().isISO8601().withMessage("startDate tidak valid"),
  query("endDate").optional().isISO8601().withMessage("endDate tidak valid"),
];

router.get("/", filters, validate, transactionController.list);
router.get("/:id", transactionController.detail);
router.post("/", rules, validate, transactionController.create);
router.put("/:id", rules, validate, transactionController.update);
router.delete("/:id", transactionController.remove);

export default router;
