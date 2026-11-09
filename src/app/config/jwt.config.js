/**
 * jwt.config.js
 * Configuración central para tokens JWT y ciclo de vida de sesiones.
 * Los secretos se obtienen estrictamente desde las variables de entorno.
 */
const env = require("./env.config");

module.exports = {
  ACCESS_TOKEN_SECRET: env.JWT.ACCESS_SECRET,
  REFRESH_TOKEN_SECRET: env.JWT.REFRESH_SECRET,
  ACCESS_TOKEN_EXPIRES_IN: env.JWT.ACCESS_EXP,
  REFRESH_TOKEN_EXPIRES_IN: env.JWT.REFRESH_EXP,
  COOKIE_NAME: "vork_access_token",
  REFRESH_COOKIE_NAME: "vork_refresh_token",
  COOKIE_OPTIONS: {
    httpOnly: true,
    secure: env.IS_PRODUCTION,
    sameSite: env.IS_PRODUCTION ? "strict" : "lax",
    path: "/"
  }
};
