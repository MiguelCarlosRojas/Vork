/**
 * ai.routes.js
 * Rutas para el motor Vork AI Chat
 */
const express = require("express");
const router = express.Router();
const aiController = require("./controller/ai.controller");

router.post(["/chat", "/ai/chat"], (req, res) => aiController.chat(req, res));

module.exports = router;
