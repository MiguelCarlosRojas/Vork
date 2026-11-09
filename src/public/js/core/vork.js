/**
 * Vork Client SDK v1.0.0
 * 
 * Librería de cliente para el ecosistema Vork:
 * - Persistencia de configuración en cookies (vork_lang).
 * - Traducción en lote en 1 sola consulta HTTP.
 * - Integración con los 9 pilares de Vork (Traductor, TTS, Conversor, Stems, Imágenes, Fondo IA, Draw, CLI, Desktop).
 */

(function (root, factory) {
  if (typeof define === "function" && define.amd) {
    define([], factory);
  } else if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.Vork = factory();
  }
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const COOKIE_NAME = "vork_lang";
  const LEGACY_COOKIE = "cloud_translator_lang";

  function setCookie(name, value, days = 365) {
    try {
      const d = new Date();
      d.setTime(d.getTime() + (days * 24 * 60 * 60 * 1000));
      const expires = "expires=" + d.toUTCString();
      document.cookie = `${name}=${encodeURIComponent(value)};${expires};path=/;SameSite=Lax`;
    } catch (e) {
      console.warn("[Vork] Error al persistir cookie:", e);
    }
  }

  function getCookie(name) {
    try {
      const match = document.cookie.match(new RegExp("(?:^|; )" + name.replace(/([\.$?*|{}\(\)\[\]\\\/\+^])/g, "\\$1") + "=([^;]*)"));
      return match ? decodeURIComponent(match[1]) : null;
    } catch (e) {
      return null;
    }
  }

  class VorkClient {
    constructor(options = {}) {
      this.apiEndpoint = options.apiEndpoint || options.endpoint || "/api/translate";
      this.currentLang = getCookie(COOKIE_NAME) || getCookie(LEGACY_COOKIE) || "original";
      this.cache = new Map();
      this.originalTexts = new Map();
      this.isTranslating = false;
    }

    getSavedLanguage() {
      return this.currentLang || getCookie(COOKIE_NAME) || "original";
    }

    async translatePage(targetLang) {
      if (!targetLang || targetLang === "original" || targetLang === "es") {
        return this.restoreOriginal();
      }

      this.isTranslating = true;
      setCookie(COOKIE_NAME, targetLang);
      setCookie(LEGACY_COOKIE, targetLang);

      try {
        const textNodes = this.extractTranslatableNodes();
        if (textNodes.length === 0) return;

        const uniqueTexts = Array.from(new Set(textNodes.map(n => n.nodeValue.trim()))).filter(Boolean);

        const uncached = uniqueTexts.filter(t => !this.cache.has(`${targetLang}:${t}`));

        if (uncached.length > 0) {
          const res = await fetch(this.apiEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ texts: uncached, to: targetLang })
          });

          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const data = await res.json();
          const translations = data.translatedTexts || data.translations || [];

          uncached.forEach((original, idx) => {
            const trans = translations[idx];
            if (trans) this.cache.set(`${targetLang}:${original}`, trans);
          });
        }

        textNodes.forEach(node => {
          const val = node.nodeValue.trim();
          const translated = this.cache.get(`${targetLang}:${val}`);
          if (translated) {
            if (!this.originalTexts.has(node)) {
              this.originalTexts.set(node, node.nodeValue);
            }
            node.nodeValue = node.nodeValue.replace(val, translated);
          }
        });

        this.currentLang = targetLang;
      } catch (err) {
        console.error("[Vork] Fallo en traducción:", err);
      } finally {
        this.isTranslating = false;
      }
    }

    restoreOriginal() {
      this.originalTexts.forEach((originalVal, node) => {
        try {
          if (node.parentNode) node.nodeValue = originalVal;
        } catch (e) {}
      });
      this.originalTexts.clear();
      this.currentLang = "original";
      setCookie(COOKIE_NAME, "original");
      setCookie(LEGACY_COOKIE, "original");
    }

    translateToEnglish() {
      return this.translatePage("en");
    }

    extractTranslatableNodes() {
      const nodes = [];
      const walker = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_TEXT,
        {
          acceptNode(node) {
            if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
            const parent = node.parentElement;
            if (!parent) return NodeFilter.FILTER_REJECT;
            const tag = parent.tagName.toLowerCase();
            if (["script", "style", "noscript", "svg", "code", "pre"].includes(tag)) {
              return NodeFilter.FILTER_REJECT;
            }
            if (parent.closest("[data-no-translate]") || parent.closest(".no-translate")) {
              return NodeFilter.FILTER_REJECT;
            }
            return NodeFilter.FILTER_ACCEPT;
          }
        }
      );

      while (walker.nextNode()) {
        nodes.push(walker.currentNode);
      }
      return nodes;
    }
  }

  return VorkClient;
});
