/**
 * routes/index.js
 * Router central de la API de Vork
 * Consolida los 9 pilares de la plataforma bajo una arquitectura modular.
 */
const express = require("express");
const router = express.Router();

const baseRoutes = require("./baseRoutes");
const translateRoutes = require("./translateRoutes");
const ttsRoutes = require("./ttsRoutes");
const voiceCloneRoutes = require("./voiceCloneRoutes");
const mediaRoutes = require("./mediaRoutes");
const separatorRoutes = require("./separatorRoutes");
const cliRoutes = require("./cliRoutes");
const imageRoutes = require("./imageRoutes");
const aiRoutes = require("./aiRoutes");

// Montar submódulos de la API
router.use("/", baseRoutes);
router.use("/", translateRoutes);
router.use("/", ttsRoutes);
router.use("/", voiceCloneRoutes);
router.use("/", mediaRoutes);
router.use("/", separatorRoutes);
router.use("/", cliRoutes);
router.use("/image", imageRoutes);
router.use("/ai", aiRoutes);
router.use("/", aiRoutes);

module.exports = router;
