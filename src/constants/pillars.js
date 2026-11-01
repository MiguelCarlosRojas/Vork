/**
 * Constantes y Metadatos de la Arquitectura de Vork
 */

const PILLARS = [
  "1. Vork Traductor (+200 idiomas por lotes en una sola consulta)",
  "2. Vork Voz Neuronal (TTS Studio con síntesis multilingüe)",
  "3. Vork Clonación Vocal (Clonación de voz por IA y recreación tímbrica)",
  "4. Vork Conversor Multimedia (YouTube, TikTok, Instagram a MP3 / MP4)",
  "5. Vork Separador de Stems (Aislamiento de voz e instrumentos con Demucs v4)",
  "6. Vork Procesador de Imágenes (Conversor y optimizador entre PNG, JPG, WEBP, ICO, AVIF)",
  "7. Vork Estudio y Fondo IA (Aislamiento inteligente de siluetas y composición)",
  "8. Vork Generador de Imágenes IA (FLUX.1 Neural sin marca de agua 100% gratis)",
  "9. Vork CLI & Agentes (Entorno de terminal, automatización y agentes autónomos)"
];

const API_ENDPOINTS = {
  translate: "POST /api/translate",
  tts: "POST /api/tts",
  voiceClone: "POST /api/voice-clone",
  mediaInfo: "POST /api/media/info",
  mediaConvert: "POST /api/media/convert",
  mediaBatch: "POST /api/media/batch",
  mediaStream: "GET /api/media/stream",
  mediaDownload: "GET /api/media/download",
  mediaPlatforms: "GET /api/media/platforms",
  separatorProcess: "POST /api/separator/process",
  separatorStream: "GET /api/separator/stream",
  separatorDownload: "GET /api/separator/download",
  cliInfo: "GET /api/cli/info",
  cliInstallPs1: "GET /cli/install.ps1",
  cliInstallCmd: "GET /cli/install.cmd",
  imageFormats: "GET /api/image/formats",
  imageConvert: "POST /api/image/convert",
  imageRemoveBg: "POST /api/image/remove-background",
  imageGenerate: "POST /api/image/generate",
  imageStream: "GET /api/image/stream",
  imageDownload: "GET /api/image/download",
  languages: "GET /api/languages",
  health: "GET /api/health",
  ping: "GET /api/ping"
};

module.exports = {
  PILLARS,
  API_ENDPOINTS
};
