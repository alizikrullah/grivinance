import { Router } from "express";
import { body } from "express-validator";
import * as walletController from "../controllers/wallet.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { validate } from "../middlewares/validate.middleware";

const router = Router();
router.use(requireAuth);

const rules = [
  body("name").trim().notEmpty().withMessage("Nama wallet wajib diisi"),
  body("type").isIn(["e_wallet", "bank", "cash"]).withMessage("Tipe wallet tidak valid"),
  body("icon").trim().notEmpty().withMessage("Icon wajib diisi"),
  body("color").matches(/^#[0-9A-Fa-f]{6}$/).withMessage("Warna harus format #RRGGBB"),
  body("balance").optional().isDecimal().withMessage("Saldo harus angka"),
];

router.get("/", walletController.list);
router.post("/", rules, validate, walletController.create);
router.put("/:id", rules, validate, walletController.update);
router.delete("/:id", walletController.remove);

export default router;
