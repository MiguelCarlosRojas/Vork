/**
 * cloudinary.service.js
 * Servicio de almacenamiento y entrega optimizada de medios con Cloudinary.
 */
const axios = require("axios");
const crypto = require("crypto");
const fs = require("fs");
const { CLOUDINARY } = require("../config/env.config");

class CloudinaryService {
  constructor() {
    this.cloudName = CLOUDINARY.CLOUD_NAME;
    this.apiKey = CLOUDINARY.API_KEY;
    this.apiSecret = CLOUDINARY.API_SECRET;
  }

  get isConfigured() {
    return Boolean(this.cloudName && this.apiKey && this.apiSecret);
  }

  /**
   * Genera firma SHA-1 para subidas autenticadas a Cloudinary
   */
  generateSignature(paramsToSign) {
    const sorted = Object.keys(paramsToSign)
      .sort()
      .map(k => `${k}=${paramsToSign[k]}`)
      .join("&");
    return crypto.createHash("sha1").update(sorted + this.apiSecret).digest("hex");
  }

  /**
   * Sube una imagen o archivo multimedia a Cloudinary
   * @param {string|Buffer} file Buffer de datos o ruta local del archivo
   * @param {object} options
   * @returns {Promise<{success: boolean, secureUrl?: string, publicId?: string, error?: string}>}
   */
  async upload(file, options = {}) {
    if (!this.isConfigured) {
      return {
        success: true,
        simulated: true,
        secureUrl: typeof file === "string" ? file : "https://res.cloudinary.com/demo/image/upload/sample.jpg"
      };
    }

    try {
      const timestamp = Math.floor(Date.now() / 1000);
      const folder = options.folder || "vork_media";
      const paramsToSign = { folder, timestamp };
      const signature = this.generateSignature(paramsToSign);

      const FormData = require("form-data");
      const form = new FormData();
      form.append("file", file);
      form.append("api_key", this.apiKey);
      form.append("timestamp", timestamp.toString());
      form.append("signature", signature);
      form.append("folder", folder);

      const res = await axios.post(
        `https://api.cloudinary.com/v1_1/${this.cloudName}/auto/upload`,
        form,
        { headers: form.getHeaders(), timeout: 30000 }
      );

      return {
        success: true,
        secureUrl: res.data?.secure_url,
        publicId: res.data?.public_id,
        format: res.data?.format,
        bytes: res.data?.bytes
      };
    } catch (err) {
      return { success: false, error: err.response?.data?.error?.message || err.message };
    }
  }
}

module.exports = new CloudinaryService();
