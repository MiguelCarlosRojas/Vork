/**
 * translateRoutes.js
 * Rutas para el Pilar 01: Traductor en la Nube (+200 idiomas por lotes)
 */
const express = require("express");
const router = express.Router();
const { rateLimiter, validateRequest } = require("../middlewares");
const { translateController } = require("../controllers");

router.route("/translate")
  .get(rateLimiter.translateLimiter, validateRequest, translateController.translateText)
  .post(rateLimiter.translateLimiter, validateRequest, translateController.translateText);

router.route("/translate/download")
  .get(translateController.downloadTranslation)
  .post(translateController.downloadTranslation);

module.exports = router;
