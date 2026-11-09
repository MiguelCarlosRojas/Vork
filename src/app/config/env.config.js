/**
 * env.config.js
 * Carga centralizada y tipada de variables de entorno (.env.production / .env).
 * Ninguna credencial o secreto sensible reside en el código; todo se inyecta por process.env.
 */
const path = require("path");
const fs = require("fs");

// Prioridad de carga: .env.production > .env > variables de entorno del sistema
const candidatePaths = [
  path.resolve(process.cwd(), ".env.production"),
  path.resolve(process.cwd(), ".env"),
  path.resolve(__dirname, "../../.env.production"),
  path.resolve(__dirname, "../../.env")
].filter(Boolean);

const envPath = candidatePaths.find(p => fs.existsSync(p));

if (envPath) {
  try {
    require("dotenv").config({ path: envPath });
  } catch {
    if (typeof process.loadEnvFile === "function") {
      try { process.loadEnvFile(envPath); } catch {}
    }
  }
}

const nodeEnv = process.env.NODE_ENV || "development";
const isProd = nodeEnv === "production";

// Validación de seguridad en producción
if (isProd && (!process.env.JWT_ACCESS_SECRET || !process.env.JWT_REFRESH_SECRET)) {
  console.warn("⚠️ ALERTA DE SEGURIDAD: JWT_ACCESS_SECRET o JWT_REFRESH_SECRET no están definidos en las variables de entorno de producción.");
}

module.exports = {
  // 1. Servidor y Red
  NODE_ENV: nodeEnv,
  IS_PRODUCTION: isProd,
  PORT: parseInt(process.env.PORT, 10) || 3000,
  APP_URL: process.env.APP_URL || "",
  API_URL: process.env.API_URL || "",
  TRUST_PROXY: process.env.TRUST_PROXY || 1,

  // 2. Timeouts del Servidor
  SERVER_TIMEOUTS: {
    KEEP_ALIVE: parseInt(process.env.SERVER_KEEP_ALIVE_TIMEOUT, 10) || 65000,
    HEADERS: parseInt(process.env.SERVER_HEADERS_TIMEOUT, 10) || 66000,
    GRACEFUL: parseInt(process.env.SERVER_GRACEFUL_TIMEOUT, 10) || 10000
  },

  // 3. Logs
  LOG_LEVEL: process.env.LOG_LEVEL || "info",
  LOGS_DIR: process.env.LOGS_DIR || "logs",

  // 4. Límites de Carga
  BODY_LIMIT: process.env.BODY_LIMIT || "2mb",
  HEAVY_BODY_LIMIT: process.env.HEAVY_BODY_LIMIT || "50mb",

  // 5. Seguridad CORS
  CORS_ORIGIN: process.env.CORS_ORIGIN || "*",

  // 6. Autenticación JWT y Sesiones (Cero secretos hardcodeados)
  JWT: {
    ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || "",
    REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || "",
    ACCESS_EXP: process.env.JWT_ACCESS_EXP || "15m",
    REFRESH_EXP: process.env.JWT_REFRESH_EXP || "7d"
  },

  // 7. Anti-Bot & Captcha (Cloudflare Turnstile & Google reCAPTCHA)
  CAPTCHA: {
    TURNSTILE_SITE_KEY: process.env.CLOUDFLARE_TURNSTILE_SITE_KEY || "",
    TURNSTILE_SECRET_KEY: process.env.CLOUDFLARE_TURNSTILE_SECRET_KEY || "",
    RECAPTCHA_SITE_KEY: process.env.RECAPTCHA_SITE_KEY || "",
    RECAPTCHA_SECRET_KEY: process.env.RECAPTCHA_SECRET_KEY || ""
  },

  // 8. Cloudflare CDN & Zona
  CLOUDFLARE: {
    API_TOKEN: process.env.CLOUDFLARE_API_TOKEN || "",
    ZONE_ID: process.env.CLOUDFLARE_ZONE_ID || ""
  },

  // 9. Cloudinary (CDN de Medios)
  CLOUDINARY: {
    CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || "",
    API_KEY: process.env.CLOUDINARY_API_KEY || "",
    API_SECRET: process.env.CLOUDINARY_API_SECRET || ""
  },

  // 10. Rate Limiting (Prevención DoS)
  RATE_LIMIT: {
    GLOBAL_MAX: parseInt(process.env.RATE_LIMIT_GLOBAL_MAX, 10) || 600,
    GLOBAL_WINDOW_MS: parseInt(process.env.RATE_LIMIT_GLOBAL_WINDOW_MS, 10) || 900000,
    TRANSLATE_MAX: parseInt(process.env.RATE_LIMIT_TRANSLATE_MAX, 10) || 100,
    TRANSLATE_WINDOW_MS: parseInt(process.env.RATE_LIMIT_TRANSLATE_WINDOW_MS, 10) || 60000,
    TTS_MAX: parseInt(process.env.RATE_LIMIT_TTS_MAX, 10) || 35,
    TTS_WINDOW_MS: parseInt(process.env.RATE_LIMIT_TTS_WINDOW_MS, 10) || 60000,
    MEDIA_MAX: parseInt(process.env.RATE_LIMIT_MEDIA_MAX, 10) || 25,
    MEDIA_WINDOW_MS: parseInt(process.env.RATE_LIMIT_MEDIA_WINDOW_MS, 10) || 60000,
    SEPARATOR_MAX: parseInt(process.env.RATE_LIMIT_SEPARATOR_MAX, 10) || 10,
    SEPARATOR_WINDOW_MS: parseInt(process.env.RATE_LIMIT_SEPARATOR_WINDOW_MS, 10) || 60000,
    IMAGE_MAX: parseInt(process.env.RATE_LIMIT_IMAGE_MAX, 10) || 30,
    IMAGE_WINDOW_MS: parseInt(process.env.RATE_LIMIT_IMAGE_WINDOW_MS, 10) || 60000
  },

  // 11. Caché en RAM (TTLs y Límites)
  CACHE: {
    TRANSLATION_MAX: parseInt(process.env.CACHE_TRANSLATION_MAX, 10) || 10000,
    TRANSLATION_TTL_MS: parseInt(process.env.CACHE_TRANSLATION_TTL_MS, 10) || 86400000,
    MEDIA_TTL_MS: parseInt(process.env.CACHE_MEDIA_TTL_MS, 10) || 1800000,
    STEMS_TTL_MS: parseInt(process.env.CACHE_STEMS_TTL_MS, 10) || 1800000,
    IMAGE_TTL_MS: parseInt(process.env.CACHE_IMAGE_TTL_MS, 10) || 3600000,
    CAPTCHA_TTL_MS: parseInt(process.env.CACHE_CAPTCHA_TTL_MS, 10) || 300000
  },

  // 12. Inteligencia Artificial (HF Token)
  AI: {
    HF_TOKEN: process.env.HF_TOKEN || ""
  },

  // Códigos de Estado HTTP estándar
  STATUS_CODES: {
    OK: 200,
    CREATED: 201,
    NO_CONTENT: 204,
    BAD_REQUEST: 400,
    UNAUTHORIZED: 401,
    FORBIDDEN: 403,
    NOT_FOUND: 404,
    CONFLICT: 409,
    TOO_MANY_REQUESTS: 429,
    SERVER_ERROR: 500
  },

  POPULAR_LANGUAGES: ["en", "es", "fr", "de", "it", "pt", "ja", "zh-CN", "ru", "ko"]
};
