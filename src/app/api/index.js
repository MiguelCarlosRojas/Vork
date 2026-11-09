/**
 * api/index.js
 * Enrutador maestro que monta todos los módulos de negocio de la API.
 */
const express = require("express");
const router = express.Router();

const translateRoutes = require("./translate/translate.routes");
const ttsRoutes = require("./tts/tts.routes");
const mediaRoutes = require("./media/media.routes");
const separatorRoutes = require("./separator/separator.routes");
const imageRoutes = require("./image/image.routes");
const aiRoutes = require("./ai/ai.routes");

// Montar cada módulo de negocio
router.use("/", translateRoutes);
router.use("/", ttsRoutes);
router.use("/", mediaRoutes);
router.use("/", separatorRoutes);
router.use("/image", imageRoutes);
router.use("/", imageRoutes);
router.use("/ai", aiRoutes);
router.use("/", aiRoutes);

module.exports = router;
