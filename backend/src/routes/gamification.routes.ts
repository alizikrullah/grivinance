import { Router } from "express";
import * as gamificationController from "../controllers/gamification.controller";
import { requireAuth } from "../middlewares/auth.middleware";

const router = Router();
router.use(requireAuth);

router.get("/", gamificationController.state);
router.post("/missions/:key/claim", gamificationController.claim);

export default router;
