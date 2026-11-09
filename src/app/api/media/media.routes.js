/**
 * media.routes.js
 * Rutas para el módulo de Conversión Multimedia Universal
 */
const express = require("express");
const router = express.Router();
const rateLimiter = require("../../config/rateLimiter.config");
const mediaController = require("./controller/media.controller");

router.get("/media/platforms", mediaController.getPlatforms);
router.post("/media/info", rateLimiter.mediaLimiter, mediaController.getMediaInfo);
router.get("/media/thumbnail-proxy", mediaController.getThumbnailProxy);
router.get("/media/thumbnail", mediaController.getThumbnail);
router.post("/media/convert", rateLimiter.mediaLimiter, mediaController.convertMedia);
router.post("/media/batch", rateLimiter.mediaLimiter, mediaController.batchConvert);
router.get("/media/stream", mediaController.streamMedia);
router.get("/media/download", mediaController.downloadMedia);

module.exports = router;
