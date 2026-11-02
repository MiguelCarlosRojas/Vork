/**
 * Rate Limiter Middleware - Protección contra ataques de Denegación de Servicio (DoS / DDoS)
 * y Fuerza Bruta en Vork.
 */

const rateLimit = require("express-rate-limit");

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
 * Permite hasta 600 peticiones cada 15 minutos por IP.
 * Ignora /api/ping y /api/health para garantizar monitores de uptime y keep-alive en Render.
 */
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 600,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => {
    return req.path === "/api/ping" || req.path === "/api/health";
  },
  handler: createRateLimitHandler(
    "Has superado el límite de peticiones globales al servidor. Por favor, espera unos minutos.",
    900
  )
});

/**
 * 2. Limitador para Traducción (/api/translate)
 * Permite hasta 100 traducciones por minuto por IP.
 */
const translateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Has superado el límite de traducciones permitidas (100 peticiones/min). Por favor disminuye la frecuencia.",
    60
  )
});

/**
 * 3. Limitador para Texto a Voz (/api/tts)
 * Permite hasta 35 operaciones de síntesis vocal por minuto por IP.
 */
const ttsLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 35,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Has alcanzado el límite de generación de voz neuronal (35 peticiones/min).",
    60
  )
});


/**
 * 5. Limitador para Conversor Multimedia (/api/media/convert, /api/media/batch, /api/media/info)
 * Operaciones que involucran transcodificación FFmpeg: hasta 25 conversiones por minuto por IP.
 */
const mediaLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 25,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Límite de conversiones multimedia alcanzado (25 peticiones/min).",
    60
  )
});

/**
 * 6. Limitador para Separador de Pistas e Instrumental (/api/separator/process)
 * Operación con redes Demucs y STFT (alto consumo de CPU): hasta 10 procesos por minuto por IP.
 */
const separatorLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Límite de separación instrumental alcanzado (10 peticiones/min).",
    60
  )
});

/**
 * 7. Limitador para Procesamiento de Imágenes y Estudio de Fondo IA (/api/image/*)
 * Operación con Pillow y Rembg ONNX: hasta 30 peticiones por minuto por IP.
 */
const imageLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  handler: createRateLimitHandler(
    "Límite de procesamiento de imágenes con IA alcanzado (30 peticiones/min). Por favor espera un momento.",
    60
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
