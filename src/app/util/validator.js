/**
 * validator.js
 * Utilidades completas de validación, sanitización, guard SSRF y esquemas.
 */
const dns = require("dns");
const path = require("path");
const { promisify } = require("util");
const lookupAsync = promisify(dns.lookup);

// --- 1. VALIDACIONES DE TIPOS BÁSICOS ---
function isString(val) {
  return typeof val === "string";
}

function isNonEmptyString(val) {
  return typeof val === "string" && val.trim().length > 0;
}

function isArrayOfStrings(val) {
  return Array.isArray(val) && val.every(item => typeof item === "string");
}

function isEmail(email) {
  if (!isNonEmptyString(email)) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function isUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

// --- 2. VALIDACIÓN DE ESQUEMAS GENÉRICOS ---
function validateSchema(data, schema) {
  const errors = [];

  for (const [field, rules] of Object.entries(schema)) {
    const val = data ? data[field] : undefined;

    if (rules.required && (val === undefined || val === null || val === "")) {
      errors.push(`El campo '${field}' es requerido.`);
      continue;
    }

    if (val !== undefined && val !== null) {
      if (rules.type === "string" && typeof val !== "string") {
        errors.push(`El campo '${field}' debe ser un string.`);
      } else if (rules.type === "number" && typeof val !== "number") {
        errors.push(`El campo '${field}' debe ser un número.`);
      } else if (rules.type === "boolean" && typeof val !== "boolean") {
        errors.push(`El campo '${field}' debe ser un booleano.`);
      } else if (rules.type === "array" && !Array.isArray(val)) {
        errors.push(`El campo '${field}' debe ser un arreglo.`);
      }

      if (rules.enum && !rules.enum.includes(val)) {
        errors.push(`El campo '${field}' tiene un valor inválido. Permitidos: ${rules.enum.join(", ")}`);
      }

      if (rules.min && typeof val === "string" && val.length < rules.min) {
        errors.push(`El campo '${field}' debe tener al menos ${rules.min} caracteres.`);
      }

      if (rules.max && typeof val === "string" && val.length > rules.max) {
        errors.push(`El campo '${field}' no puede exceder ${rules.max} caracteres.`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

// --- 3. SSRF GUARD (Protección contra Server-Side Request Forgery) ---
function isPrivateIP(ip) {
  if (!ip || typeof ip !== "string") return true;
  const cleanIp = ip.trim().toLowerCase();

  if (
    cleanIp === "::1" ||
    cleanIp === "::" ||
    cleanIp.startsWith("fc") ||
    cleanIp.startsWith("fd") ||
    cleanIp.startsWith("fe80") ||
    cleanIp.startsWith("ff") ||
    cleanIp === "0:0:0:0:0:0:0:1"
  ) {
    return true;
  }

  if (cleanIp.startsWith("::ffff:")) {
    const ipv4Part = cleanIp.substring(7);
    return isPrivateIP(ipv4Part);
  }

  const parts = cleanIp.split(".").map(p => parseInt(p, 10));
  if (parts.length !== 4 || parts.some(n => isNaN(n) || n < 0 || n > 255)) {
    return true;
  }

  const [b0, b1] = parts;
  if (b0 === 127) return true; // Loopback
  if (b0 === 10) return true;  // RFC 1918 Class A
  if (b0 === 172 && b1 >= 16 && b1 <= 31) return true; // RFC 1918 Class B
  if (b0 === 192 && b1 === 168) return true; // RFC 1918 Class C
  if (b0 === 169 && b1 === 254) return true; // Link-local
  if (b0 === 100 && b1 >= 64 && b1 <= 127) return true; // CGNAT
  if (b0 === 0 || b0 >= 224) return true; // Broadcast / Multicast

  return false;
}

async function validateSafeUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== "string") {
    throw new Error("La URL proporcionada es inválida o está vacía.");
  }

  let parsed;
  try {
    parsed = new URL(rawUrl.trim());
  } catch {
    throw new Error("El formato de la URL no es válido.");
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("Protocolo no seguro. Solo se admiten enlaces HTTP o HTTPS.");
  }

  const hostname = parsed.hostname;
  if (!hostname || hostname.toLowerCase() === "localhost") {
    throw new Error("Acceso denegado a hosts locales.");
  }

  if (/^(\d{1,3}\.){3}\d{1,3}$/.test(hostname) && isPrivateIP(hostname)) {
    throw new Error("Acceso bloqueado: la IP solicitada es privada o reservada.");
  }

  try {
    const resolved = await lookupAsync(hostname, { all: true });
    for (const record of resolved) {
      if (isPrivateIP(record.address)) {
        throw new Error("Acceso bloqueado: el nombre de dominio resuelve a una IP de red privada interna.");
      }
    }
  } catch (err) {
    if (err.message.includes("Acceso bloqueado")) throw err;
    throw new Error(`No se pudo resolver el dominio '${hostname}'.`);
  }

  return true;
}

// --- 4. SANITIZACIÓN DE IDENTIFICADORES Y CABECERAS ---
function sanitizeId(id) {
  if (!id || typeof id !== "string") return null;
  const trimmed = id.trim();
  if (!/^[a-zA-Z0-9_\-]+$/.test(trimmed) || trimmed.length > 128) {
    return null;
  }
  return trimmed;
}

function sanitizeFilenameHeader(raw, fallback = "archivo_descarga") {
  if (!raw || typeof raw !== "string") return fallback;
  const clean = raw
    .replace(/[\r\n\t"]/g, "")
    .replace(/[^\x20-\x7E]/g, "_")
    .trim();
  return clean.slice(0, 100) || fallback;
}

function isPathContained(targetPath, allowedBaseDir) {
  if (!targetPath || !allowedBaseDir) return false;
  const resolvedTarget = path.resolve(targetPath);
  const resolvedBase = path.resolve(allowedBaseDir);
  return resolvedTarget.startsWith(resolvedBase);
}

// --- 5. MIDDLEWARE DE VALIDACIÓN DE TRADUCCIÓN ---
function validateRequest(req, res, next) {
  const data = req.method === "GET" ? req.query : req.body;
  if (!data || typeof data !== "object") {
    return res.status(400).json({
      success: false,
      error: "Cuerpo de solicitud inválido o ausente."
    });
  }

  const rawTarget = data.targetLanguage || data.to || data.target_language;
  if (!rawTarget || typeof rawTarget !== "string" || !rawTarget.trim()) {
    return res.status(400).json({
      success: false,
      error: "El idioma objetivo es requerido. Proporcione 'targetLanguage' o 'to'."
    });
  }

  next();
}

module.exports = {
  isString,
  isNonEmptyString,
  isArrayOfStrings,
  isEmail,
  isUrl,
  validateSchema,
  isPrivateIP,
  validateSafeUrl,
  sanitizeId,
  sanitizeFilenameHeader,
  isPathContained,
  validateRequest
};
