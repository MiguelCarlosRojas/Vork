/**
 * cookies.js
 * Utilidad unificada y segura para manipulación de cookies (Zero localStorage)
 */

(function (window) {
  "use strict";

  function setCookie(name, value, days = 365) {
    try {
      let expires = "";
      if (days) {
        const d = new Date();
        d.setTime(d.getTime() + (days * 24 * 60 * 60 * 1000));
        expires = "; expires=" + d.toUTCString();
      }
      document.cookie = `${name}=${encodeURIComponent(value || "")}${expires}; path=/; SameSite=Lax`;
    } catch (e) {
      console.warn("[CookiesUtil] Error al fijar cookie:", e);
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

  function deleteCookie(name) {
    try {
      document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:01 GMT; path=/; SameSite=Lax`;
    } catch (e) {}
  }

  window.CookieUtil = {
    set: setCookie,
    get: getCookie,
    delete: deleteCookie
  };
})(window);
