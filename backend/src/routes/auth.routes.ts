import express, { Router } from "express";
import { body } from "express-validator";
import * as authController from "../controllers/auth.controller";
import { requireAuth } from "../middlewares/auth.middleware";
import { calendarDateRule, validate } from "../middlewares/validate.middleware";
import { wibDateKey } from "../utils/date.utils";

const router = Router();

const refreshTokenRule = body("refreshToken").isString().notEmpty().withMessage("Refresh token wajib diisi");

// Titik di nama akun Gmail dipertahankan, supaya email yang tampil sama dengan
// yang diketik user. Akun lama yang tersimpan tanpa titik tetap ketemu: lihat
// emailVariants di auth.service.
const emailRule = body("email")
  .isEmail()
  .withMessage("Email tidak valid")
  .normalizeEmail({ gmail_remove_dots: false });

const newPasswordRule = (field: string) =>
  body(field).isLength({ min: 8 }).withMessage("Password minimal 8 karakter");

router.post(
  "/register",
  emailRule,
  newPasswordRule("password"),
  body("name").trim().notEmpty().withMessage("Nama wajib diisi"),
  validate,
  authController.register,
);

router.post(
  "/login",
  emailRule,
  body("password").notEmpty().withMessage("Password wajib diisi"),
  validate,
  authController.login,
);

router.post(
  "/refresh",
  refreshTokenRule,
  body("rotate").optional().isBoolean(),
  validate,
  authController.refresh,
);

router.delete("/logout", refreshTokenRule, validate, authController.logout);

router.get("/me", requireAuth, authController.me);

router.put(
  "/me",
  requireAuth,
  body("name").trim().notEmpty().withMessage("Nama wajib diisi").isLength({ max: 60 }),
  body("nickname")
    .optional({ values: "falsy" })
    .isString()
    .trim()
    .isLength({ max: 30 })
    .withMessage("Nama panggilan maksimal 30 karakter"),
  body("phone")
    .optional({ values: "falsy" })
    .isString()
    .customSanitizer((value: string) => value.replace(/[\s-]/g, ""))
    .matches(/^\+?\d{8,15}$/)
    .withMessage("Nomor HP harus 8-15 digit, boleh diawali +"),
  calendarDateRule(body("birthDate").optional({ values: "falsy" }), "Tanggal lahir")
    .bail()
    .custom((value: string) => value >= "1900-01-01" && value <= wibDateKey(new Date()))
    .withMessage("Tanggal lahir tidak masuk akal"),
  validate,
  authController.updateProfile,
);

router.put(
  "/me/email",
  requireAuth,
  emailRule,
  body("currentPassword").notEmpty().withMessage("Password lama wajib diisi"),
  validate,
  authController.changeEmail,
);

router.put(
  "/me/password",
  requireAuth,
  body("currentPassword").notEmpty().withMessage("Password lama wajib diisi"),
  newPasswordRule("newPassword"),
  validate,
  authController.changePassword,
);

router.get("/me/avatar", requireAuth, authController.avatar);

// Byte gambar mentah, bukan multipart: HP sudah mengecilkan fotonya, jadi
// express.raw bawaan cukup tanpa multer. Lewat 1 MB → 413 dari body-parser.
router.put(
  "/me/avatar",
  requireAuth,
  express.raw({ type: ["image/jpeg", "image/png", "image/webp"], limit: "1mb" }),
  authController.setAvatar,
);

router.delete("/me/avatar", requireAuth, authController.deleteAvatar);

export default router;
