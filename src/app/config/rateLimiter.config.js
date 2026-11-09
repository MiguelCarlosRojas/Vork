/**
 * rateLimiter.config.js
 * Protección contra ataques de Denegación de Servicio (DoS / DDoS) y Fuerza Bruta en Vork.
 * Todos los límites y ventanas son configurables dinámicamente mediante .env.production.
 */
const rateLimit = require("express-rate-limit");
const env = require("./env.config");

/**
 * Generador estándar de respuestas JSON para exceso de peticiones (HTTP 429)
 */
function createRateLimitHandler(customMessage, windowSeconds) {
  return (req, res, next, options) => {
    res.status(429).json({
      status: "error",
      success: false,
      statusCode: 429,
      error: customMessage || "Límite de solicitudes alcanzado. Por favor intente más tarde.",
      retryAfterSeconds: windowSeconds
    });
  };
}

/**
 * 1. Limitador Global: Aplica a todas las rutas generales y navegación de la SPA
 */
const globalLimiter = rateLimit({
  windowMs: env.RATE_LIMIT.GLOBAL_WINDOW_MS,
  max: env.RATE_LIMIT.GLOBAL_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.path === "/api/ping" || req.path === "/api/health",
  handler: createRateLimitHandler(
    "Has superado el límite de peticiones globales al servidor. Por favor, espera unos minutos.",
    Math.round(env.RATE_LIMIT.GLOBAL_WINDOW_MS / 1000)
  )
});

/**
 * 2. Limitador para Traducción (/api/translate)
 */
const translateLimiter = rateLimit({
  windowMs: env.RATE_LIMIT.TRANSLATE_WINDOW_MS,
  max: env.RATE_LIMIT.TRANSLATE_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Has superado el límite de traducciones permitidas. Por favor disminuye la frecuencia.",
    Math.round(env.RATE_LIMIT.TRANSLATE_WINDOW_MS / 1000)
  )
});

/**
 * 3. Limitador para Texto a Voz (/api/tts)
 */
const ttsLimiter = rateLimit({
  windowMs: env.RATE_LIMIT.TTS_WINDOW_MS,
  max: env.RATE_LIMIT.TTS_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Has alcanzado el límite de generación de voz neuronal.",
    Math.round(env.RATE_LIMIT.TTS_WINDOW_MS / 1000)
  )
});

/**
 * 4. Limitador para Conversor Multimedia (/api/media/*)
 */
const mediaLimiter = rateLimit({
  windowMs: env.RATE_LIMIT.MEDIA_WINDOW_MS,
  max: env.RATE_LIMIT.MEDIA_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Límite de conversiones multimedia alcanzado.",
    Math.round(env.RATE_LIMIT.MEDIA_WINDOW_MS / 1000)
  )
});

/**
 * 5. Limitador para Separador de Pistas e Instrumental (/api/separator/*)
 */
const separatorLimiter = rateLimit({
  windowMs: env.RATE_LIMIT.SEPARATOR_WINDOW_MS,
  max: env.RATE_LIMIT.SEPARATOR_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Límite de separación instrumental alcanzado.",
    Math.round(env.RATE_LIMIT.SEPARATOR_WINDOW_MS / 1000)
  )
});

/**
 * 6. Limitador para Procesamiento de Imágenes y Estudio de Fondo IA (/api/image/*)
 */
const imageLimiter = rateLimit({
  windowMs: env.RATE_LIMIT.IMAGE_WINDOW_MS,
  max: env.RATE_LIMIT.IMAGE_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Límite de procesamiento de imágenes con IA alcanzado. Por favor espera un momento.",
    Math.round(env.RATE_LIMIT.IMAGE_WINDOW_MS / 1000)
  )
});

module.exports = {
  globalLimiter,
  translateLimiter,
  ttsLimiter,
  mediaLimiter,
  separatorLimiter,
  imageLimiter
};
