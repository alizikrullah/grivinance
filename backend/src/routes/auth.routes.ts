import { Router } from "express";
import { body } from "express-validator";
import * as authController from "../controllers/auth.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { validate } from "../middlewares/validate.middleware";

const router = Router();

const refreshTokenRule = body("refreshToken").isString().notEmpty().withMessage("Refresh token wajib diisi");

router.post(
  "/register",
  body("email").isEmail().withMessage("Email tidak valid").normalizeEmail(),
  body("password").isLength({ min: 8 }).withMessage("Password minimal 8 karakter"),
  body("name").trim().notEmpty().withMessage("Nama wajib diisi"),
  validate,
  authController.register,
);

router.post(
  "/login",
  body("email").isEmail().withMessage("Email tidak valid").normalizeEmail(),
  body("password").notEmpty().withMessage("Password wajib diisi"),
  validate,
  authController.login,
);

router.post("/refresh", refreshTokenRule, validate, authController.refresh);

router.get("/me", requireAuth, authController.me);

router.delete("/logout", refreshTokenRule, validate, authController.logout);

export default router;
