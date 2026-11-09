/**
 * refreshToken.service.js
 * Servicio de ciclo de vida de tokens de refresco, rotación y revocación.
 */
const crypto = require("crypto");
const jwtConfig = require("../config/jwt.config");

class RefreshTokenService {
  constructor() {
    // Almacén en memoria para tokens activos (sustituible por base de datos o Redis)
    this.tokenStore = new Map();
    this.revokedTokens = new Set();
  }

  /**
   * Genera y almacena un nuevo refresh token asociado a un usuario
   * @param {string} userId
   * @param {object} [metadata]
   * @returns {string} Token opaco seguro
   */
  generateRefreshToken(userId, metadata = {}) {
    const token = crypto.randomBytes(40).toString("hex");
    const expiresAt = Date.now() + 7 * 24 * 60 * 60 * 1000; // 7 días

    this.tokenStore.set(token, {
      userId,
      expiresAt,
      createdAt: Date.now(),
      ...metadata
    });

    return token;
  }

  /**
   * Valida un refresh token
   * @param {string} token
   * @returns {{ valid: boolean, userId?: string, reason?: string }}
   */
  validateRefreshToken(token) {
    if (!token || this.revokedTokens.has(token)) {
      return { valid: false, reason: "Token revocado o inválido" };
    }

    const session = this.tokenStore.get(token);
    if (!session) {
      return { valid: false, reason: "Sesión no encontrada" };
    }

    if (Date.now() > session.expiresAt) {
      this.tokenStore.delete(token);
      return { valid: false, reason: "Token expirado" };
    }

    return { valid: true, userId: session.userId, session };
  }

  /**
   * Rota el refresh token por uno nuevo (Previene replay attacks)
   * @param {string} oldToken
   * @returns {{ success: boolean, newToken?: string, error?: string }}
   */
  rotateRefreshToken(oldToken) {
    const check = this.validateRefreshToken(oldToken);
    if (!check.valid) {
      return { success: false, error: check.reason };
    }

    // Revoca el token anterior
    this.revokeRefreshToken(oldToken);

    // Emite el nuevo
    const newToken = this.generateRefreshToken(check.userId);
    return { success: true, newToken, userId: check.userId };
  }

  /**
   * Revoca un token específico
   * @param {string} token
   */
  revokeRefreshToken(token) {
    this.tokenStore.delete(token);
    this.revokedTokens.add(token);
  }

  /**
   * Revoca todas las sesiones de un usuario
   * @param {string} userId
   */
  revokeAllUserTokens(userId) {
    for (const [token, data] of this.tokenStore.entries()) {
      if (data.userId === userId) {
        this.revokeRefreshToken(token);
      }
    }
  }
}

module.exports = new RefreshTokenService();
