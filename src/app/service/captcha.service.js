/**
 * captcha.service.js
 * Servicio de validación de tokens de Captcha (Cloudflare Turnstile y Google reCAPTCHA v2/v3).
 */
const axios = require("axios");
const { CAPTCHA } = require("../config/env.config");

class CaptchaService {
  constructor() {
    this.turnstileSecret = CAPTCHA.TURNSTILE_SECRET_KEY;
    this.recaptchaSecret = CAPTCHA.RECAPTCHA_SECRET_KEY;
  }

  /**
   * Valida un token de Cloudflare Turnstile
   * @param {string} token Token enviado por el cliente
   * @param {string} [remoteIp] IP del cliente
   * @returns {Promise<{success: boolean, errorCodes?: string[]}>}
   */
  async verifyTurnstile(token, remoteIp = "") {
    if (!token) return { success: false, errorCodes: ["missing-input-response"] };
    if (!this.turnstileSecret) {
      // Modo desarrollo permisivo si no hay secret configurado
      return { success: true, simulated: true };
    }

    try {
      const formData = new URLSearchParams();
      formData.append("secret", this.turnstileSecret);
      formData.append("response", token);
      if (remoteIp) formData.append("remoteip", remoteIp);

      const response = await axios.post("https://challenges.cloudflare.com/turnstile/v0/siteverify", formData, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        timeout: 5000
      });

      return {
        success: Boolean(response.data?.success),
        errorCodes: response.data?.["error-codes"] || []
      };
    } catch (err) {
      return { success: false, errorCodes: [err.message] };
    }
  }

  /**
   * Valida un token de Google reCAPTCHA
   * @param {string} token 
   * @param {string} [remoteIp]
   */
  async verifyRecaptcha(token, remoteIp = "") {
    if (!token) return { success: false, errorCodes: ["missing-input-response"] };
    if (!this.recaptchaSecret) return { success: true, simulated: true };

    try {
      const response = await axios.post("https://www.google.com/recaptcha/api/siteverify", null, {
        params: {
          secret: this.recaptchaSecret,
          response: token,
          remoteip: remoteIp
        },
        timeout: 5000
      });

      return {
        success: Boolean(response.data?.success),
        score: response.data?.score,
        errorCodes: response.data?.["error-codes"] || []
      };
    } catch (err) {
      return { success: false, errorCodes: [err.message] };
    }
  }
}

module.exports = new CaptchaService();
