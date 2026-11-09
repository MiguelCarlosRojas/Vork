/**
 * clipboard.js
 * Utilidad reutilizable para copiar texto al portapapeles con feedback visual en el botón.
 */

(function (window) {
  "use strict";

  /**
   * Copia el texto de un elemento al portapapeles y provee feedback visual al botón disparador
   * @param {HTMLElement|string} btn - Botón o selector del botón
   * @param {string} elementId - ID del elemento cuyo contenido se copiará
   * @param {string} [feedbackText="COPIADO"] - Texto que se mostrará temporalmente
   */
  function copiarAlPortapapeles(btn, elementId, feedbackText = "COPIADO") {
    const el = document.getElementById(elementId);
    if (!el) return;

    const buttonElement = typeof btn === "string" ? document.querySelector(btn) : btn;
    const texto = el.innerText || el.textContent;

    if (!navigator.clipboard) {
      // Fallback para navegadores antiguos
      const textArea = document.createElement("textarea");
      textArea.value = texto.trim();
      document.body.appendChild(textArea);
      textArea.select();
      try {
        document.execCommand("copy");
        showFeedback(buttonElement, feedbackText);
      } catch (err) {
        console.error("Error al copiar texto:", err);
      }
      document.body.removeChild(textArea);
      return;
    }

    navigator.clipboard.writeText(texto.trim()).then(() => {
      showFeedback(buttonElement, feedbackText);
    }).catch(err => {
      console.error("Error al copiar al portapapeles:", err);
    });
  }

  function showFeedback(btn, feedbackText = "¡Copiado!") {
    if (!btn) return;
    const originalHTML = btn.innerHTML;

    btn.classList.add("btn-copied");
    btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="15" height="15" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>${feedbackText}</span>`;

    setTimeout(() => {
      btn.classList.remove("btn-copied");
      btn.innerHTML = originalHTML;
    }, 2000);
  }

  window.copiarAlPortapapeles = copiarAlPortapapeles;
  window.ClipboardUtil = { copy: copiarAlPortapapeles };
})(window);
