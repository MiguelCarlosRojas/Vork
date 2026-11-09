/**
 * jwtCookies.js
 * Manejo seguro de tokens JWT en cookies HTTPOnly y SameSite.
 */
const jwtConfig = require("../config/jwt.config");

/**
 * Establece el access token y opcionalmente el refresh token en cookies de respuesta
 * @param {import("express").Response} res
 * @param {string} accessToken
 * @param {string} [refreshToken]
 */
function setAuthCookies(res, accessToken, refreshToken = null) {
  res.cookie(jwtConfig.COOKIE_NAME, accessToken, {
    ...jwtConfig.COOKIE_OPTIONS,
    maxAge: 15 * 60 * 1000 // 15 minutos
  });

  if (refreshToken) {
    res.cookie(jwtConfig.REFRESH_COOKIE_NAME, refreshToken, {
      ...jwtConfig.COOKIE_OPTIONS,
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 días
    });
  }
}

/**
 * Obtiene el token de autenticación desde cookies o cabecera Authorization Bearer
 * @param {import("express").Request} req
 * @returns {string|null}
 */
function getAuthTokenFromRequest(req) {
  // 1. Cabecera Authorization Bearer
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    return authHeader.substring(7).trim();
  }

  // 2. Cookie firmada o parseada
  if (req.cookies && req.cookies[jwtConfig.COOKIE_NAME]) {
    return req.cookies[jwtConfig.COOKIE_NAME];
  }

  // 3. Parser manual si cookie-parser no está montado
  const cookieHeader = req.headers.cookie;
  if (cookieHeader) {
    const match = cookieHeader.match(new RegExp(`(^|;\\s*)${jwtConfig.COOKIE_NAME}=([^;]+)`));
    if (match) return decodeURIComponent(match[2]);
  }

  return null;
}

/**
 * Limpia las cookies de autenticación (Logout)
 * @param {import("express").Response} res
 */
function clearAuthCookies(res) {
  res.clearCookie(jwtConfig.COOKIE_NAME, { path: "/" });
  res.clearCookie(jwtConfig.REFRESH_COOKIE_NAME, { path: "/" });
}

module.exports = {
  setAuthCookies,
  getAuthTokenFromRequest,
  clearAuthCookies
};
