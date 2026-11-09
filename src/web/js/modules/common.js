/**
 * common.js
 * Inicialización estándar de Vork para páginas informativas y legales.
 */

(function (window, document) {
  "use strict";

  function initTranslator() {
    if (window.Vork && !window.translator) {
      window.translator = new window.Vork({
        endpoint: "/api/translate",
        useCookies: true,
        batchSize: 500
      });
    }

    const btnEnglish = document.getElementById("btn-english");
    const btnRestore = document.getElementById("btn-restore");
    const selectLang = document.getElementById("select-lang");
    const btnTranslateCustom = document.getElementById("btn-translate-custom");
    const inputCustomLang = document.getElementById("input-custom-lang");

    if (btnEnglish && !btnEnglish._bound) {
      btnEnglish._bound = true;
      btnEnglish.onclick = () => window.translator && window.translator.translateToEnglish();
    }
    if (btnRestore && !btnRestore._bound) {
      btnRestore._bound = true;
      btnRestore.onclick = () => window.translator && window.translator.restoreOriginal();
    }
    if (selectLang && !selectLang._bound) {
      selectLang._bound = true;
      selectLang.onchange = (e) => window.translator && window.translator.translatePage(e.target.value);
    }
    if (btnTranslateCustom && !btnTranslateCustom._bound) {
      btnTranslateCustom._bound = true;
      btnTranslateCustom.onclick = () => {
        const val = (inputCustomLang?.value || "").trim().toLowerCase();
        if (val && window.translator) window.translator.translatePage(val);
      };
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initTranslator);
  } else {
    initTranslator();
  }

  window.initCommonTranslator = initTranslator;
})(window, document);
