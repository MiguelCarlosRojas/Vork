/**
 * tts.routes.js
 * Rutas para el Pilar 02: TTS Neuronal y Síntesis de Voz
 */
const express = require("express");
const router = express.Router();
const ttsController = require("./controller/tts.controller");
const rateLimiter = require("../../config/rateLimiter.config");

router.get("/tts/voices", (req, res) => ttsController.getVoices(req, res));
router.post("/tts/synthesize", rateLimiter.ttsLimiter, (req, res) => ttsController.synthesize(req, res));
router.get("/tts/stream", (req, res) => ttsController.streamTts(req, res));
router.get("/tts/download", (req, res) => ttsController.downloadTts(req, res));

module.exports = router;
