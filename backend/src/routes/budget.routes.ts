import { Router } from "express";
import { body, query } from "express-validator";
import * as budgetController from "../controllers/budget.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { moneyRule, validate } from "../middlewares/validate.middleware";

const router = Router();
router.use(requireAuth);

router.get(
  "/",
  query("year").isInt({ min: 2000, max: 2100 }).withMessage("Tahun tidak valid"),
  query("month").isInt({ min: 1, max: 12 }).withMessage("Bulan harus 1-12"),
  validate,
  budgetController.list,
);

// Satu budget per kategori, jadi kategorinya sekaligus jadi kunci: PUT = atur atau ganti.
router.put(
  "/:categoryId",
  moneyRule(body("amount"), "Budget", { positive: true }),
  validate,
  budgetController.set,
);

router.delete("/:categoryId", budgetController.remove);

export default router;
