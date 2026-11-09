/**
 * jwtUtils.js
 * Firmado, verificación y decodificación de tokens JSON Web Token (JWT).
 */
const crypto = require("crypto");
const jwtConfig = require("../config/jwt.config");

function base64UrlEncode(str) {
  return Buffer.from(str)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function base64UrlDecode(str) {
  str = str.replace(/-/g, "+").replace(/_/g, "/");
  while (str.length % 4) str += "=";
  return Buffer.from(str, "base64").toString();
}

/**
 * Firma un payload y retorna un JWT (HS256)
 * @param {object} payload
 * @param {string} [secret]
 * @param {number} [expiresInSeconds]
 * @returns {string} Token JWT
 */
function signToken(payload, secret = jwtConfig.ACCESS_TOKEN_SECRET, expiresInSeconds = 900) {
  if (!secret) {
    throw new Error("JWT_ACCESS_SECRET no está configurado en las variables de entorno.");
  }
  const header = { alg: "HS256", typ: "JWT" };
  const exp = Math.floor(Date.now() / 1000) + expiresInSeconds;
  const iat = Math.floor(Date.now() / 1000);

  const fullPayload = { ...payload, iat, exp };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));

  const signature = crypto
    .createHmac("sha256", secret)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

/**
 * Verifica y valida la firma y expiración de un JWT
 * @param {string} token
 * @param {string} [secret]
 * @returns {{ valid: boolean, payload?: any, error?: string }}
 */
function verifyToken(token, secret = jwtConfig.ACCESS_TOKEN_SECRET) {
  if (!secret) {
    return { valid: false, error: "JWT_ACCESS_SECRET no está configurado en las variables de entorno." };
  }
  if (!token || typeof token !== "string") {
    return { valid: false, error: "Token ausente o inválido" };
  }

  const parts = token.split(".");
  if (parts.length !== 3) {
    return { valid: false, error: "Formato de token inválido" };
  }

  const [headerB64, payloadB64, signatureB64] = parts;

  const expectedSignature = crypto
    .createHmac("sha256", secret)
    .update(`${headerB64}.${payloadB64}`)
    .digest("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  if (signatureB64 !== expectedSignature) {
    return { valid: false, error: "Firma de token inválida" };
  }

  try {
    const payload = JSON.parse(base64UrlDecode(payloadB64));
    if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) {
      return { valid: false, error: "Token expirado", expired: true };
    }
    return { valid: true, payload };
  } catch (err) {
    return { valid: false, error: "Error al decodificar payload" };
  }
}

/**
 * Decodifica sin verificar firma
 */
function decodeToken(token) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    return JSON.parse(base64UrlDecode(parts[1]));
  } catch {
    return null;
  }
}

module.exports = {
  signToken,
  verifyToken,
  decodeToken
};
