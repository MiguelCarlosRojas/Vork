/**
 * Vork Components - Sistema Modular de Componentes Reutilizables
 * Centraliza la estructura de Encabezado (Navbar), Cajón Móvil (Mobile Drawer),
 * Pie de Página (Footer) y Controles de Interfaz para todo el ecosistema Vork.
 * Diseñado bajo la estética editorial orgánica y cálida inspirada en Huella.
 */

(function (window, document) {
  "use strict";

  const CloudComponents = {
    version: "3.0.0",

    /**
     * Detecta la pestaña activa según la URL actual
     */
    detectActiveNav() {
      try {
        const p = (window.location.pathname || "/").toLowerCase();
        if (p === "/" || p === "/index.html") return "home";
        if (p.startsWith("/docs")) return "docs";
        if (p.startsWith("/support")) return "support";
        if (p.startsWith("/status")) return "status";
        if (p.startsWith("/translator")) return "translator";
        if (p.startsWith("/tts")) return "tts";
        if (p.startsWith("/voice-clone")) return "voice-clone";
        if (p.startsWith("/converter") || p.startsWith("/media")) return "converter";
        if (p.startsWith("/vocal-remover") || p.startsWith("/separator") || p.startsWith("/stems")) return "vocal-remover";
        if (p.startsWith("/dj") || p.startsWith("/cloud-dj")) return "dj";
        if (p.startsWith("/image-converter") || p.startsWith("/img")) return "image-converter";
        if (p.startsWith("/background-remover") || p.startsWith("/bg-remover") || p.startsWith("/ai-background")) return "background-remover";
        if (p.startsWith("/cli") || p.startsWith("/terminal")) return "cli";
        if (p.startsWith("/donate")) return "donate";
        if (p.startsWith("/api")) return "api";
        if (p.startsWith("/learn")) return "learn";
        if (p.startsWith("/help")) return "help";
        if (p.startsWith("/terms")) return "terms";
        if (p.startsWith("/privacy")) return "privacy";
        if (p.startsWith("/security")) return "security";
        return "";
      } catch (e) {
        return "home";
      }
    },

    /**
     * Plantilla HTML del Encabezado y Barra Flotante
     */
    getHeaderHTML(activeNav = "home") {
      const active = activeNav || this.detectActiveNav();
      return `
<header class="top-nav no-translate" data-no-translate id="main-header" data-mounted="true">
  <div class="nav-container header-inner-full">
    <div class="brand-group">
      <a href="/" class="brand-link brand-wrapper" title="Vork - Inicio">
        <span class="brand-logo-mark"><img src="/img/logo.png" alt="Vork Logo" class="brand-img" width="36" height="36"></span>
        <span class="brand-title">vork<i>.</i></span>
        <span class="brand-subtitle">ecosistema<br>multimodal</span>
      </a>
      <span class="badge badge-brand">v3.0.0</span>
    </div>

    <nav class="desktop-nav nav-links-full" aria-label="Navegación Principal">
      <a href="/" class="${active === "home" ? "active" : ""}">Inicio</a>
      <a href="/docs" class="${active === "docs" ? "active" : ""}">Docs</a>
      <a href="/support" class="${active === "support" ? "active" : ""}">Soporte</a>
      <a href="/status" class="${active === "status" ? "active" : ""}">Estado</a>
    </nav>

    <div class="toolbar-controls translation-controls-full">
      <button id="btn-english" class="btn btn-english btn-sm" title="Traducir instantáneamente al inglés">
        <svg class="icon" viewBox="0 0 24 24" width="16" height="16"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20M12 2a14.5 14.5 0 0 1 0 20M2 12h20"/></svg>
        <span>English</span>
      </button>

      <div class="selector-box lang-selector-group">
        <div class="selector-dropdown select-wrapper">
          <select id="select-lang" class="select-sm" aria-label="Seleccionar idioma de traducción" title="Seleccionar idioma">
            <option value="es">Español (es)</option>
            <option value="en">English (en)</option>
            <option value="fr">Français (fr)</option>
            <option value="de">Deutsch (de)</option>
            <option value="it">Italiano (it)</option>
            <option value="pt">Portugués (pt)</option>
            <option value="ja">日本語 (ja)</option>
            <option value="zh-CN">中文 (zh-CN)</option>
            <option value="ru">Русский (ru)</option>
          </select>
        </div>
        <div class="custom-lang-group">
          <input type="text" id="input-custom-lang" placeholder="ISO" maxlength="5" title="Código ISO personalizado (ej: ja, fr, de)">
          <button id="btn-translate-custom" class="btn btn-primary btn-sm" title="Traducir a código ISO">GO</button>
        </div>
      </div>

      <button id="btn-restore" class="btn btn-outline btn-sm" title="Restaurar idioma original">
        <svg class="icon" viewBox="0 0 24 24" width="15" height="15"><path d="M3 12a9 9 0 0 1 15-6.7L21 8M21 3v5h-5M21 12a9 9 0 0 1-15 6.7L3 16M3 21v-5h5"/></svg>
        <span>Original</span>
      </button>

      <div id="status-pill" class="status-pill" title="Estado del microservicio Vork">
        <span class="pulse"></span>
        <span id="status-text">LISTO</span>
      </div>
    </div>

    <button id="menu-toggle-btn" class="menu-toggle-btn" aria-label="Abrir Menú de Navegación Lateral">
      <span class="hamburger-line"></span>
      <span class="hamburger-line"></span>
      <span class="hamburger-line"></span>
    </button>
  </div>
</header>

<div id="drawer-backdrop"></div>

<aside id="mobile-drawer" class="mobile-drawer no-translate" data-no-translate>
  <div class="drawer-header">
    <a href="/" class="drawer-brand">
      <span class="brand-logo-mark"><img src="/img/logo.png" alt="Vork Logo" class="brand-img" width="36" height="36"></span>
      <span class="brand-title">vork<i>.</i></span>
    </a>
    <button id="drawer-close-btn" class="drawer-close-btn" aria-label="Cerrar Menú Lateral">
      <svg class="icon" viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
    </button>
  </div>

  <div class="drawer-body">
    <div class="drawer-section">
      <span class="drawer-title">LOS 9 PILARES DE VORK</span>
      <ul class="drawer-menu">
        <li><a href="/translator" class="${active === "translator" ? "active" : ""}"><span class="nav-num">01</span> Traductor en la Nube</a></li>
        <li><a href="/tts" class="${active === "tts" ? "active" : ""}"><span class="nav-num">02</span> Texto a Voz (TTS)</a></li>
        <li><a href="/voice-clone" class="${active === "voice-clone" ? "active" : ""}"><span class="nav-num">03</span> Clonación de Voz IA</a></li>
        <li><a href="/converter" class="${active === "converter" ? "active" : ""}"><span class="nav-num">04</span> Conversor Multimedia</a></li>
        <li><a href="/vocal-remover" class="${active === "vocal-remover" ? "active" : ""}"><span class="nav-num">05</span> Separador de Stems</a></li>
        <li><a href="/dj" class="${active === "dj" ? "active" : ""}"><span class="nav-num">06</span> Vork DJ Mezclador</a></li>
        <li><a href="/image-converter" class="${active === "image-converter" ? "active" : ""}"><span class="nav-num">07</span> Conversor de Imágenes</a></li>
        <li><a href="/background-remover" class="${active === "background-remover" ? "active" : ""}"><span class="nav-num">08</span> Estudio y Fondo IA</a></li>
        <li><a href="/cli" class="${active === "cli" ? "active" : ""}"><span class="nav-num">09</span> Vork CLI Terminal</a></li>
      </ul>
    </div>

    <div class="drawer-section">
      <span class="drawer-title">NAVEGACIÓN DEL PORTAL</span>
      <ul class="drawer-menu">
        <li><a href="/" class="${active === "home" ? "active" : ""}"><svg class="icon" viewBox="0 0 24 24"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg> Inicio</a></li>
        <li><a href="/docs" class="${active === "docs" ? "active" : ""}"><svg class="icon" viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg> Documentación</a></li>
        <li><a href="/support" class="${active === "support" ? "active" : ""}"><svg class="icon" viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg> Soporte</a></li>
        <li><a href="/status" class="${active === "status" ? "active" : ""}"><svg class="icon" viewBox="0 0 24 24"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg> Estado Servidor</a></li>
        <li><a href="/donate" class="${active === "donate" ? "active" : ""}"><svg class="icon" viewBox="0 0 24 24"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/></svg> Donaciones</a></li>
      </ul>
    </div>
  </div>
</aside>
`;
    },

    /**
     * Plantilla HTML del Pie de Página Horizontal
     */
    getFooterHTML(activePage = "") {
      const active = activePage || this.detectActiveNav();
      return `
<footer class="footer-full site-footer" id="main-footer" data-mounted="true">
  <div class="footer-inner-full">
    <div class="footer-col footer-col-brand">
      <h4>
        <span class="brand-logo-mark"><img src="/img/logo.png" alt="Vork Logo" class="brand-img" width="36" height="36"></span>
        <span>vork<i>.</i></span>
      </h4>
      <p>Ecosistema cloud multimodal de alto rendimiento: traducción neuronal distribuida (+200 idiomas), Voz Neuronal TTS, Clonación Vocal IA, Conversor Multimedia Universal MP3/MP4, Separador de Stems, Vork DJ y Vork CLI con Agentes Autónomos.</p>
      <p style="font-size: 0.85rem; color: var(--muted); margin-top: 14px; display: flex; align-items: center; gap: 8px;">
        <span class="pulse"></span>
        <span>Microservicio autónomo activo • <b>v3.0.0 ONLINE</b></span>
      </p>
    </div>

    <div class="footer-col">
      <h4>Servicios</h4>
      <ul>
        <li><a href="/voice-clone" class="${active === "voice-clone" ? "active" : ""}">Clonación de Voz IA</a></li>
        <li><a href="/dj" class="${active === "dj" ? "active" : ""}">Vork DJ Mezclador</a></li>
        <li><a href="/image-converter" class="${active === "image-converter" ? "active" : ""}">Conversor de Imágenes</a></li>
        <li><a href="/background-remover" class="${active === "background-remover" ? "active" : ""}">Estudio de Fondo IA</a></li>
      </ul>
    </div>

    <div class="footer-col">
      <h4>Recursos</h4>
      <ul>
        <li><a href="/api" class="${active === "api" ? "active" : ""}">API REST Vork</a></li>
        <li><a href="/docs" class="${active === "docs" ? "active" : ""}">Documentación</a></li>
        <li><a href="/learn" class="${active === "learn" ? "active" : ""}">Guías de Integración</a></li>
        <li><a href="/help" class="${active === "help" ? "active" : ""}">Centro de Ayuda</a></li>
      </ul>
    </div>

    <div class="footer-col">
      <h4>Información Legal</h4>
      <ul>
        <li><a href="/terms" class="${active === "terms" ? "active" : ""}">Términos del Servicio</a></li>
        <li><a href="/privacy" class="${active === "privacy" ? "active" : ""}">Política de Privacidad</a></li>
        <li><a href="/security" class="${active === "security" ? "active" : ""}">Seguridad y Cookies</a></li>
        <li><a href="/donate" class="${active === "donate" ? "active" : ""}">Donaciones y Apoyo</a></li>
      </ul>
    </div>
  </div>

  <div class="footer-bottom-full">
    <span>© 2026 Vork. Todos los derechos reservados.</span>
    <span>Plataforma Multimodal de Alto Rendimiento</span>
  </div>
</footer>
`;
    },

    /**
     * Monta o reemplaza el Encabezado en los contenedores especificados
     */
    renderHeader() {
      const targets = document.querySelectorAll("#header-placeholder, #vork-header, [data-component='header']");
      targets.forEach(target => {
        if (target.getAttribute("data-mounted") === "true") return;
        const activeNav = target.getAttribute("data-active") || this.detectActiveNav();
        target.outerHTML = this.getHeaderHTML(activeNav);
      });
    },

    /**
     * Monta o reemplaza el Pie de Página en los contenedores especificados
     */
    renderFooter() {
      const targets = document.querySelectorAll("#footer-placeholder, #vork-footer, [data-component='footer']");
      targets.forEach(target => {
        if (target.getAttribute("data-mounted") === "true") return;
        const activePage = target.getAttribute("data-active") || this.detectActiveNav();
        target.outerHTML = this.getFooterHTML(activePage);
      });
    },

    /**
     * Sincroniza el idioma en el selector según la cookie o estado global
     */
    syncLanguageState() {
      try {
        const savedLang = window.translator ? window.translator.getSavedLanguage() : null;
        const select = document.getElementById("select-lang");
        if (select && savedLang) {
          select.value = savedLang;
        }
      } catch (e) {}
    },

    /**
     * Inicializa eventos del drawer móvil con delegación global e idempotencia
     */
    initDrawerEvents() {
      if (window._drawerEventsBound) return;
      window._drawerEventsBound = true;

      document.addEventListener("click", (e) => {
        const toggleBtn = e.target.closest("#menu-toggle-btn");
        const drawer = document.getElementById("mobile-drawer");
        const backdrop = document.getElementById("drawer-backdrop");

        if (toggleBtn) {
          e.preventDefault();
          e.stopPropagation();
          if (!drawer) return;
          const isOpen = drawer.classList.contains("open");
          if (isOpen) {
            drawer.classList.remove("open");
            toggleBtn.classList.remove("active");
            if (backdrop) backdrop.classList.remove("open");
            document.body.classList.remove("drawer-open");
          } else {
            drawer.classList.add("open");
            toggleBtn.classList.add("active");
            if (backdrop) backdrop.classList.add("open");
            document.body.classList.add("drawer-open");
          }
          return;
        }

        const closeBtn = e.target.closest("#drawer-close-btn");
        const backdropClick = e.target.closest("#drawer-backdrop");
        const drawerLink = e.target.closest("#mobile-drawer a");

        if (closeBtn || backdropClick || drawerLink) {
          if (drawer) drawer.classList.remove("open");
          const btn = document.getElementById("menu-toggle-btn");
          if (btn) btn.classList.remove("active");
          if (backdrop) backdrop.classList.remove("open");
          document.body.classList.remove("drawer-open");
        }
      });

      document.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
          const drawer = document.getElementById("mobile-drawer");
          const backdrop = document.getElementById("drawer-backdrop");
          const btn = document.getElementById("menu-toggle-btn");
          if (drawer && drawer.classList.contains("open")) {
            drawer.classList.remove("open");
            if (btn) btn.classList.remove("active");
            if (backdrop) backdrop.classList.remove("open");
            document.body.classList.remove("drawer-open");
          }
        }
      });
    },

    /**
     * Delegación de eventos para la barra de traducción del encabezado
     */
    initToolbarEvents() {
      if (window._toolbarEventsBound) return;
      window._toolbarEventsBound = true;

      document.addEventListener("click", (e) => {
        const btnEnglish = e.target.closest("#btn-english");
        if (btnEnglish) {
          e.preventDefault();
          if (window.translator) window.translator.translateToEnglish();
          else if (window.Vork) window.Vork.translateToEnglish();
          return;
        }

        const btnRestore = e.target.closest("#btn-restore");
        if (btnRestore) {
          e.preventDefault();
          if (window.translator) window.translator.restoreOriginal();
          else if (window.Vork) window.Vork.restoreOriginal();
          return;
        }

        const btnTranslateCustom = e.target.closest("#btn-translate-custom");
        if (btnTranslateCustom) {
          e.preventDefault();
          const input = document.getElementById("input-custom-lang");
          const val = (input?.value || "").trim().toLowerCase();
          if (val) {
            if (window.translator) window.translator.translatePage(val);
            else if (window.Vork) window.Vork.translatePage(val);
          }
          return;
        }

        const btnCopyCmd = e.target.closest("#btn-copy-install, .btn-terminal-copy");
        if (btnCopyCmd) {
          e.preventDefault();
          const terminalBox = btnCopyCmd.closest(".vork-terminal-box") || document;
          const codeEl = terminalBox.querySelector("#cli-install-cmd, .cli-install-cmd, code");
          const cmdText = (codeEl?.innerText || codeEl?.textContent || "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex").trim();
          
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(cmdText).then(() => {
              const origHTML = btnCopyCmd.innerHTML;
              btnCopyCmd.classList.add("btn-copied");
              btnCopyCmd.innerHTML = `<svg class="icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> <span>¡Copiado!</span>`;
              setTimeout(() => {
                btnCopyCmd.classList.remove("btn-copied");
                btnCopyCmd.innerHTML = origHTML;
              }, 2000);
            }).catch(() => {});
          }
          return;
        }
      });

      document.addEventListener("change", (e) => {
        if (e.target && e.target.id === "select-lang") {
          const val = e.target.value;
          if (window.translator) window.translator.translatePage(val);
          else if (window.Vork) window.Vork.translatePage(val);
        }
      });

      document.addEventListener("keydown", (e) => {
        if (e.target && e.target.id === "input-custom-lang" && e.key === "Enter") {
          e.preventDefault();
          const val = e.target.value.trim().toLowerCase();
          if (val) {
            if (window.translator) window.translator.translatePage(val);
            else if (window.Vork) window.Vork.translatePage(val);
          }
        }
      });
    },

    /**
     * Inicializa eventos globales para instalación CLI y pestañas de código IDE
     */
    initGlobalInteractions() {
      if (window._globalInteractionsBound) return;
      window._globalInteractionsBound = true;

      document.addEventListener("click", (e) => {
        // 1. Botón Copiar de Instalación CLI
        const btnInstall = e.target.closest("#btn-copy-install, .btn-terminal-copy");
        if (btnInstall) {
          e.preventDefault();
          const cmdEl = document.getElementById("cli-install-cmd");
          const cmd = cmdEl?.textContent?.trim() || "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex";
          navigator.clipboard.writeText(cmd);
          btnInstall.classList.add("btn-copied");
          const originalHtml = btnInstall.innerHTML;
          btnInstall.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg> <span>¡Copiado!</span>';
          setTimeout(() => {
            btnInstall.classList.remove("btn-copied");
            btnInstall.innerHTML = originalHtml;
          }, 1800);
          return;
        }

        // 2. Pestañas de Bloques de Código IDE (.code-tab-btn)
        const tabBtn = e.target.closest(".code-tab-btn");
        if (tabBtn) {
          e.preventDefault();
          const group = tabBtn.getAttribute("data-tab-group");
          const targetId = tabBtn.getAttribute("data-tab-target");
          if (!group || !targetId) return;

          document.querySelectorAll(`.code-tab-btn[data-tab-group="${group}"]`).forEach(b => b.classList.remove("is-active"));
          document.querySelectorAll(`.code-tab-panel[data-tab-group="${group}"]`).forEach(p => p.classList.remove("is-active"));

          tabBtn.classList.add("is-active");
          const targetPanel = document.getElementById(targetId);
          if (targetPanel) targetPanel.classList.add("is-active");
          return;
        }

        // 3. Botón Copiar Bloques de Código IDE (.btn-code-copy)
        const copyBtn = e.target.closest(".btn-code-copy");
        if (copyBtn) {
          e.preventDefault();
          const targetId = copyBtn.getAttribute("data-target-code");
          const targetEl = targetId ? document.getElementById(targetId) : copyBtn.closest(".pro-code-window")?.querySelector(".code-tab-panel.is-active .pro-code-body, .pro-code-body");
          if (!targetEl) return;
          const codeText = targetEl.innerText || targetEl.textContent || "";
          navigator.clipboard.writeText(codeText);
          const origHtml = copyBtn.innerHTML;
          copyBtn.classList.add("is-copied");
          copyBtn.innerHTML = '<svg class="icon" viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg> <span>¡Copiado!</span>';
          setTimeout(() => {
            copyBtn.classList.remove("is-copied");
            copyBtn.innerHTML = origHtml;
          }, 1800);
          return;
        }
      });
    },

    /**
     * Inyecta el grano de textura (film grain) de Huella si no está presente
     */
    ensureGrain() {
      if (!document.querySelector(".grain")) {
        const grainDiv = document.createElement("div");
        grainDiv.className = "grain";
        grainDiv.setAttribute("aria-hidden", "true");
        document.body.appendChild(grainDiv);
      }
    },

    /**
     * Inicializa componentes en el DOM
     */
    init() {
      this.renderHeader();
      this.renderFooter();
      this.initDrawerEvents();
      this.initToolbarEvents();
      this.initGlobalInteractions();
      this.ensureGrain();
      this.syncLanguageState();
    }
  };

  // Exponer a nivel global
  window.CloudComponents = CloudComponents;
  window.VorkComponents = CloudComponents;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => CloudComponents.init());
  } else {
    CloudComponents.init();
  }
})(typeof window !== "undefined" ? window : this, typeof document !== "undefined" ? document : {});
