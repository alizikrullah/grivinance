import { Router } from "express";
import { body } from "express-validator";
import * as categoryController from "../controllers/category.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { validate } from "../middlewares/validate.middleware";

const router = Router();
router.use(requireAuth);

const rules = [
  body("name").trim().notEmpty().withMessage("Nama kategori wajib diisi"),
  body("type").isIn(["income", "expense"]).withMessage("Tipe kategori tidak valid"),
  body("icon").trim().notEmpty().withMessage("Icon wajib diisi"),
  body("color").matches(/^#[0-9A-Fa-f]{6}$/).withMessage("Warna harus format #RRGGBB"),
];

router.get("/", categoryController.list);
router.post("/", rules, validate, categoryController.create);
router.put("/:id", rules, validate, categoryController.update);
router.delete("/:id", categoryController.remove);

export default router;
