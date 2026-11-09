/**
 * translate.routes.js
 * Rutas del módulo de traducción.
 */
const express = require("express");
const router = express.Router();
const translateController = require("./controller/translate.controller");
const rateLimiter = require("../../config/rateLimiter.config");
const { validateRequest } = require("../../util/validator");

router.route("/translate")
  .get(rateLimiter.translateLimiter, validateRequest, (req, res, next) => translateController.translateText(req, res, next))
  .post(rateLimiter.translateLimiter, validateRequest, (req, res, next) => translateController.translateText(req, res, next));

router.get("/translate/languages", (req, res) => translateController.getLanguages(req, res));

router.route("/translate/download")
  .get((req, res) => translateController.downloadTranslation(req, res))
  .post((req, res) => translateController.downloadTranslation(req, res));

module.exports = router;
