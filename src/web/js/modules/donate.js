/**
 * donate.js
 * Lógica modular del front-end para donate.html
 */

(function (window, document) {
  "use strict";

// 1. Manejo Interactivo de Montos Sugeridos para PayPal
    document.addEventListener("click", function(e) {
      const amountBtn = e.target.closest("#paypal-amounts-group .btn-outline");
      if (amountBtn) {
        e.preventDefault();
        const allAmountBtns = document.querySelectorAll("#paypal-amounts-group .btn-outline");
        const wasActive = amountBtn.classList.contains("active");

        allAmountBtns.forEach(b => b.classList.remove("active", "is-selected"));

        const paypalBtn = document.getElementById("btn-paypal-main");
        const paypalText = document.getElementById("btn-paypal-text");
        const basePaypal = "https://paypal.me/miguelcarlosrojas";

        if (wasActive) {
          if (paypalBtn) paypalBtn.href = basePaypal;
          if (paypalText) paypalText.textContent = "Donar con PayPal Ahora";
        } else {
          amountBtn.classList.add("active", "is-selected");
          const amount = amountBtn.getAttribute("data-amount");
          if (paypalBtn) paypalBtn.href = `${basePaypal}/${amount}USD`;
          if (paypalText) paypalText.textContent = `Donar $${amount} USD con PayPal`;
        }
      }

      const paypalMain = e.target.closest("#btn-paypal-main");
      if (paypalMain) {
        const activeBtn = document.querySelector("#paypal-amounts-group .btn-outline.active, #paypal-amounts-group .btn-outline.is-selected");
        const amount = activeBtn ? activeBtn.getAttribute("data-amount") : null;
        if (amount) {
          paypalMain.href = `https://paypal.me/miguelcarlosrojas/${amount}USD`;
        } else {
          paypalMain.href = "https://paypal.me/miguelcarlosrojas";
        }
      }
    });

    // 2. Lógica del Traductor en bloque seguro
    function initDonatePage() {
      try {
        if (typeof Vork !== "undefined") {
          const apiEndpoint = "https://vork-st1k.onrender.com/api/translate";
          window.translator = new Vork({ endpoint: apiEndpoint, useCookies: true, batchSize: 500 });
          const btnEn = document.getElementById("btn-english");
          if (btnEn) btnEn.onclick = () => window.translator.translateToEnglish();
          const btnRes = document.getElementById("btn-restore");
          if (btnRes) btnRes.onclick = () => window.translator.restoreOriginal();
          const selLang = document.getElementById("select-lang");
          if (selLang) selLang.onchange = (e) => window.translator.translatePage(e.target.value);
          const btnCust = document.getElementById("btn-translate-custom");
          if (btnCust) btnCust.onclick = () => {
            const val = document.getElementById("input-custom-lang")?.value?.trim()?.toLowerCase();
            if (val) window.translator.translatePage(val);
          };
        }
      } catch (err) {
        console.warn("Vork diferido:", err);
      }
    }

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", initDonatePage);
    } else {
      initDonatePage();
    }

})(window, document);
