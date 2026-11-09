/**
 * separator.routes.js
 * Rutas para el Pilar 05: Separador de Voz e Instrumental (Demucs & Vocal Remover)
 */
const express = require("express");
const router = express.Router();
const rateLimiter = require("../../config/rateLimiter.config");
const separatorController = require("./controller/separator.controller");

router.post("/separator/process", rateLimiter.separatorLimiter, separatorController.processSeparation);
router.get("/separator/stream", separatorController.streamStem);
router.get("/separator/download", separatorController.downloadStem);

module.exports = router;
