/**
 * docs.js
 * Lógica modular del front-end para docs.html
 */

(function (window, document) {
  "use strict";

// Función global para copiar al portapapeles con feedback visual
    function copiarAlPortapapeles(btn, elementId) {
      const el = document.getElementById(elementId);
      if (!el) return;
      const texto = el.innerText || el.textContent;
      navigator.clipboard.writeText(texto.trim()).then(() => {
        const originalHTML = btn.innerHTML;
        btn.classList.add("btn-copied");
        btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg> <span>¡Copiado!</span>`;
        setTimeout(() => {
          btn.classList.remove("btn-copied");
          btn.innerHTML = originalHTML;
        }, 1800);
      }).catch(err => {
        console.error("Error al copiar:", err);
      });
    }
    window.copiarAlPortapapeles = copiarAlPortapapeles;

    document.addEventListener("DOMContentLoaded", () => {
      // 1. ScrollSpy y navegación con scroll interno en docs-main-content
      const allTargets = Array.from(document.querySelectorAll(".docs-section[id], .docs-subsection[id]"));
      const docsMain = document.querySelector(".docs-main-content");
      const sidebar = document.querySelector(".docs-sidebar");

      function setActiveNav(targetId) {
        if (!targetId) return;

        document.querySelectorAll(".docs-sidebar-session.active, .docs-sidebar-sublink.active").forEach(el => {
          el.classList.remove("active");
        });

        const activeSub = document.querySelector(`.docs-sidebar-sublink[href="#${targetId}"], .docs-sidebar-sublink[data-target="${targetId}"]`);
        const activeSession = document.querySelector(`.docs-sidebar-session[href="#${targetId}"], .docs-sidebar-session[data-target="${targetId}"]`);

        let targetLink = null;

        if (activeSub) {
          activeSub.classList.add("active");
          targetLink = activeSub;
          const parentGroup = activeSub.closest(".docs-sidebar-group");
          if (parentGroup) {
            const parentSession = parentGroup.querySelector(".docs-sidebar-session");
            if (parentSession) parentSession.classList.add("active");
          }
        } else if (activeSession) {
          activeSession.classList.add("active");
          targetLink = activeSession;
        }

        if (targetLink && sidebar) {
          const sidebarRect = sidebar.getBoundingClientRect();
          const linkRect = targetLink.getBoundingClientRect();
          if (linkRect.top < sidebarRect.top + 50 || linkRect.bottom > sidebarRect.bottom - 50) {
            targetLink.scrollIntoView({ behavior: "smooth", block: "nearest" });
          }
        }
      }

      function handleScroll() {
        if (!allTargets.length) return;
        const isDesktop = window.innerWidth > 860 && docsMain;

        if (isDesktop) {
          const mainScrollTop = docsMain.scrollTop;
          const mainScrollHeight = docsMain.scrollHeight;
          const mainClientHeight = docsMain.clientHeight;

          if (mainClientHeight + mainScrollTop >= mainScrollHeight - 100) {
            setActiveNav(allTargets[allTargets.length - 1].id);
            return;
          }

          const mainTop = docsMain.getBoundingClientRect().top;
          let currentId = null;

          for (let i = 0; i < allTargets.length; i++) {
            const el = allTargets[i];
            const elTop = el.getBoundingClientRect().top;
            if (elTop - mainTop <= 90) {
              currentId = el.id;
            } else {
              break;
            }
          }

          if (currentId) {
            setActiveNav(currentId);
          } else if (allTargets.length > 0 && mainScrollTop < 100) {
            setActiveNav(allTargets[0].id);
          }
        } else {
          const scrollY = window.scrollY || window.pageYOffset;
          const windowHeight = window.innerHeight;
          const documentHeight = document.documentElement.scrollHeight;

          if (windowHeight + scrollY >= documentHeight - 120) {
            setActiveNav(allTargets[allTargets.length - 1].id);
            return;
          }

          let currentId = null;
          for (let i = 0; i < allTargets.length; i++) {
            const el = allTargets[i];
            const top = el.getBoundingClientRect().top;
            if (top <= 140) {
              currentId = el.id;
            } else {
              break;
            }
          }

          if (currentId) {
            setActiveNav(currentId);
          } else if (allTargets.length > 0 && scrollY < 150) {
            setActiveNav(allTargets[0].id);
          }
        }
      }

      if (docsMain) {
        docsMain.addEventListener("scroll", handleScroll, { passive: true });
      }
      window.addEventListener("scroll", handleScroll, { passive: true });
      setTimeout(handleScroll, 120);

      // 2. Navegación suave al hacer clic en enlaces
      function scrollToTarget(targetId) {
        if (!targetId) return;
        const cleanId = targetId.replace(/^#/, '');
        const targetEl = document.getElementById(cleanId);
        if (!targetEl) return;

        const isDesktop = window.innerWidth > 860 && docsMain;
        if (isDesktop) {
          const mainRect = docsMain.getBoundingClientRect();
          const targetRect = targetEl.getBoundingClientRect();
          const offset = targetRect.top - mainRect.top + docsMain.scrollTop - 24;
          docsMain.scrollTo({
            top: Math.max(0, offset),
            behavior: "smooth"
          });
        } else {
          const topOffset = targetEl.getBoundingClientRect().top + window.scrollY - 84;
          window.scrollTo({
            top: Math.max(0, topOffset),
            behavior: "smooth"
          });
        }
        setActiveNav(cleanId);
      }

      document.querySelectorAll('.docs-sidebar a[href^="#"], .docs-mobile-toc-bar a[href^="#"], .docs-main-content a[href^="#"]').forEach(link => {
        link.addEventListener("click", (e) => {
          const href = link.getAttribute("href");
          if (href && href.startsWith("#") && href.length > 1) {
            e.preventDefault();
            scrollToTarget(href);
            if (history.pushState) {
              history.pushState(null, null, href);
            }
          }
        });
      });

      if (window.location.hash && window.location.hash.length > 1) {
        setTimeout(() => {
          scrollToTarget(window.location.hash);
        }, 150);
      }


      // 3. Control de Índice Rápido Móvil
      const btnToggleToc = document.getElementById("btn-toggle-docs-toc");
      const tocContent = document.getElementById("docs-mobile-toc-content");
      if (btnToggleToc && tocContent) {
        btnToggleToc.addEventListener("click", () => {
          const isClosed = tocContent.style.display === "none";
          tocContent.style.display = isClosed ? "block" : "none";
        });
        tocContent.querySelectorAll("a").forEach(a => {
          a.addEventListener("click", () => {
            tocContent.style.display = "none";
          });
        });
      }

      // 4. Inicialización del Traductor de la barra superior
      try {
        const apiEndpoint = "https://vork-st1k.onrender.com/api/translate";
        window.translator = new Vork({ endpoint: apiEndpoint, useCookies: true, batchSize: 500 });
        const btnEn = document.getElementById("btn-english");
        if (btnEn) btnEn.onclick = () => window.translator.translateToEnglish();
        const btnRest = document.getElementById("btn-restore");
        if (btnRest) btnRest.onclick = () => window.translator.restoreOriginal();
        const selLang = document.getElementById("select-lang");
        if (selLang) selLang.onchange = (e) => window.translator.translatePage(e.target.value);
        const btnCustom = document.getElementById("btn-translate-custom");
        if (btnCustom) {
          btnCustom.onclick = () => {
            const val = document.getElementById("input-custom-lang").value.trim().toLowerCase();
            if (val) window.translator.translatePage(val);
          };
        }
      } catch (e) {}
    });

})(window, document);
