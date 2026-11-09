/**
 * cloudflare.service.js
 * Servicio de integración con la API de Cloudflare (Purge cache, DNS, WAF).
 */
const axios = require("axios");
const { CLOUDFLARE } = require("../config/env.config");

class CloudflareService {
  constructor() {
    this.apiToken = CLOUDFLARE.API_TOKEN;
    this.zoneId = CLOUDFLARE.ZONE_ID;
    this.baseUrl = "https://api.cloudflare.com/client/v4";
  }

  get headers() {
    return {
      Authorization: `Bearer ${this.apiToken}`,
      "Content-Type": "application/json"
    };
  }

  /**
   * Purga archivos específicos o todo el caché de la zona en Cloudflare
   * @param {string[]} [files] URLs específicas a purgar. Si se omite, purga todo el caché.
   * @returns {Promise<{success: boolean, result?: any, error?: string}>}
   */
  async purgeCache(files = []) {
    if (!this.apiToken || !this.zoneId) {
      return { success: true, simulated: true, message: "Cloudflare token o Zone ID no configurado." };
    }

    try {
      const payload = files.length > 0 ? { files } : { purge_everything: true };
      const res = await axios.post(`${this.baseUrl}/zones/${this.zoneId}/purge_cache`, payload, {
        headers: this.headers,
        timeout: 10000
      });

      return { success: Boolean(res.data?.success), result: res.data?.result };
    } catch (err) {
      return { success: false, error: err.response?.data?.errors?.[0]?.message || err.message };
    }
  }

  /**
   * Consulta el estado de la zona
   */
  async getZoneDetails() {
    if (!this.apiToken || !this.zoneId) {
      return { success: true, simulated: true };
    }

    try {
      const res = await axios.get(`${this.baseUrl}/zones/${this.zoneId}`, {
        headers: this.headers,
        timeout: 8000
      });
      return { success: true, zone: res.data?.result };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
}

module.exports = new CloudflareService();
