import { Router } from "express";
import { query } from "express-validator";
import * as summaryController from "../controllers/summary.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { calendarDateRule, validate } from "../middlewares/validate.middleware";

const router = Router();
router.use(requireAuth);

const yearRule = query("year").isInt({ min: 2000, max: 2100 }).withMessage("Tahun tidak valid");

router.get(
  "/daily",
  calendarDateRule(query("date"), "Tanggal"),
  validate,
  summaryController.daily,
);

router.get(
  "/monthly",
  yearRule,
  query("month").isInt({ min: 1, max: 12 }).withMessage("Bulan harus 1-12"),
  validate,
  summaryController.monthly,
);

router.get("/yearly", yearRule, validate, summaryController.yearly);

export default router;
