/**
 * Vork SPA Router v1.1.0
 * 
 * Navegación fluida y sin recargas de página completas:
 * - Sincroniza dinámicamente assets (<link rel="stylesheet"> y bloques <style>) en <head>.
 * - Carga y ejecuta scripts externos e inline en el ámbito global real de window.
 * - Soporta pre-traducción en memoria y persistencia de cookies de idioma.
 * - Mantiene clases y atributos de <body> sin desconfiguración de diseño.
 * - Maneja historial (pushState/popstate), enlaces activos y desplazamiento suave a anclas.
 */

(function () {
  "use strict";

  // Crear barra de progreso superior si no existe
  let progressBar = document.getElementById("spa-progress-bar");
  if (!progressBar) {
    progressBar = document.createElement("div");
    progressBar.id = "spa-progress-bar";
    document.documentElement.appendChild(progressBar);
  }

  let progressTimer = null;
  function startProgress() {
    if (progressTimer) clearInterval(progressTimer);
    progressBar.style.opacity = "1";
    progressBar.style.width = "20%";
    let width = 20;
    progressTimer = setInterval(() => {
      if (width < 85) {
        width += (85 - width) * 0.2;
        progressBar.style.width = width + "%";
      }
    }, 100);
  }

  function finishProgress() {
    if (progressTimer) clearInterval(progressTimer);
    progressBar.style.width = "100%";
    setTimeout(() => {
      progressBar.style.opacity = "0";
      setTimeout(() => {
        progressBar.style.width = "0%";
      }, 250);
    }, 150);
  }

  window.startSpaProgress = startProgress;
  window.finishSpaProgress = finishProgress;

  let isNavigatingSpa = false;
  let abortController = null;

  // Interceptar addEventListener para invocar inmediatamente callbacks de DOMContentLoaded
  // durante la navegación SPA sin dejar residuos de listeners anteriores.
  const nativeAddEventListener = document.addEventListener.bind(document);
  document.addEventListener = function (type, listener, options) {
    if (type === "DOMContentLoaded" && isNavigatingSpa) {
      try {
        listener(new Event("DOMContentLoaded"));
      } catch (err) {
        console.warn("[SPA Router] Error en callback DOMContentLoaded:", err);
      }
      return;
    }
    return nativeAddEventListener(type, listener, options);
  };

  async function navigate(url, push = true) {
    if (abortController) {
      abortController.abort();
    }
    abortController = new AbortController();

    startProgress();
    document.body.classList.add("spa-transitioning");

    try {
      const response = await fetch(url, {
        signal: abortController.signal,
        headers: { "Accept": "text/html, */*" }
      });
      if (!response.ok) {
        window.location.href = url;
        return;
      }

      const html = await response.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // 1. Pre-traducción en memoria fluida si existe traductor activo
      const rawTitle = doc.title;
      try {
        const savedLang = window.translator ? window.translator.getSavedLanguage() : null;
        if (window.translator) {
          window.translator.setOriginalTitle(rawTitle);
          if (savedLang && savedLang !== "original" && savedLang !== "es") {
            window.translator.preTranslateDocument(doc, savedLang);
          }
        }
      } catch (transErr) {
        console.warn("[SPA Router] Advertencia en pre-traducción:", transErr);
      }

      // 2. Sincronizar Título, Idioma y Metadatos
      document.title = doc.title;
      if (doc.documentElement.lang) {
        document.documentElement.lang = doc.documentElement.lang;
      }

      // Favicons
      const currentFavicon = document.querySelector("link[rel*='icon']");
      const newFavicon = doc.querySelector("link[rel*='icon']");
      if (currentFavicon && newFavicon) {
        currentFavicon.href = newFavicon.href;
      }

      // Meta descriptions y OpenGraph
      const currentMetaDesc = document.querySelector('meta[name="description"]');
      const newMetaDesc = doc.querySelector('meta[name="description"]');
      if (currentMetaDesc && newMetaDesc) {
        currentMetaDesc.setAttribute("content", newMetaDesc.getAttribute("content") || "");
      }
      const currentOgDesc = document.querySelector('meta[property="og:description"]');
      const newOgDesc = doc.querySelector('meta[property="og:description"]');
      if (currentOgDesc && newOgDesc) {
        currentOgDesc.setAttribute("content", newOgDesc.getAttribute("content") || "");
      }
      const currentOgTitle = document.querySelector('meta[property="og:title"]');
      const newOgTitle = doc.querySelector('meta[property="og:title"]');
      if (currentOgTitle && newOgTitle) {
        currentOgTitle.setAttribute("content", newOgTitle.getAttribute("content") || "");
      }

      // 3. SINCRONIZAR HOJAS DE ESTILO Y BLOQUES <style> EN <head>
      // Limpiar estilos dinámicos de páginas anteriores
      document.head.querySelectorAll("[data-spa-injected]").forEach(el => el.remove());

      // Hojas de estilo externas (<link rel="stylesheet">)
      const existingLinks = Array.from(document.head.querySelectorAll("link[rel='stylesheet']"));
      const existingHrefs = new Set(existingLinks.map(l => {
        try { return new URL(l.getAttribute("href"), window.location.href).href; } catch { return l.getAttribute("href"); }
      }));

      const docLinks = Array.from(doc.head.querySelectorAll("link[rel='stylesheet']"));
      for (const link of docLinks) {
        try {
          const rawHref = link.getAttribute("href");
          if (!rawHref) continue;
          const resolvedHref = new URL(rawHref, window.location.href).href;
          if (!existingHrefs.has(resolvedHref)) {
            const newLink = document.createElement("link");
            Array.from(link.attributes).forEach(attr => newLink.setAttribute(attr.name, attr.value));
            newLink.setAttribute("data-spa-injected", "true");
            document.head.appendChild(newLink);
            existingHrefs.add(resolvedHref);
          }
        } catch (errLink) {
          console.warn("[SPA Router] Error al sincronizar hoja de estilo:", errLink);
        }
      }

      // Bloques de estilo <style> de la nueva página (por ej. CloudDJ, Separador de Voz)
      const docStyles = Array.from(doc.querySelectorAll("style"));
      docStyles.forEach(style => {
        const newStyle = document.createElement("style");
        Array.from(style.attributes).forEach(attr => newStyle.setAttribute(attr.name, attr.value));
        newStyle.setAttribute("data-spa-injected", "true");
        newStyle.textContent = style.textContent;
        document.head.appendChild(newStyle);
      });

      // 4. Sincronizar contenido y clases de <body>
      document.body.className = doc.body.className || "";
      document.body.innerHTML = doc.body.innerHTML;
      document.body.classList.remove("spa-transitioning");

      // 5. Renderizar componentes modulares (Encabezado / Pie de Página / Modales)
      if (window.CloudComponents && typeof window.CloudComponents.init === "function") {
        try {
          window.CloudComponents.init();
        } catch (compErr) {
          console.warn("[SPA Router] Error al inicializar componentes:", compErr);
        }
      }

      // 6. Actualizar historial del navegador
      if (push) {
        window.history.pushState({ spa: true, url: url }, doc.title, url);
      }

      // 7. Sincronizar y ejecutar scripts de la nueva página en orden secuencial
      isNavigatingSpa = true;
      try {
        const scripts = Array.from(document.body.querySelectorAll("script"));
        // Remover elementos originales del body para evitar residuos inactivos
        scripts.forEach(s => s.remove());

        for (const script of scripts) {
          try {
            const src = script.getAttribute("src");
            if (src) {
              const resolvedSrc = new URL(src, window.location.href).href;
              const isCoreScript = resolvedSrc.includes("spa-router.js") || resolvedSrc.includes("components.js");
              if (isCoreScript) {
                continue;
              }

              // Si es el SDK estático de traducción y ya está activo, no recargarlo
              if (resolvedSrc.includes("vork.js") && window.Vork) {
                continue;
              }

              // Scripts de módulos y utilidades de la página: cargar y ejecutar
              await new Promise((resolve) => {
                const newScript = document.createElement("script");
                Array.from(script.attributes).forEach(attr => newScript.setAttribute(attr.name, attr.value));
                newScript.onload = () => resolve();
                newScript.onerror = () => {
                  console.warn("[SPA Router] No se pudo cargar script externo:", src);
                  resolve();
                };
                document.body.appendChild(newScript);
              });
            } else {
              // Script inline: creamos elemento <script> real para ejecutar en ámbito window global
              const inlineScript = document.createElement("script");
              Array.from(script.attributes).forEach(attr => inlineScript.setAttribute(attr.name, attr.value));
              inlineScript.textContent = script.textContent;
              document.body.appendChild(inlineScript);
            }
          } catch (scriptErr) {
            console.warn("[SPA Router] Error al ejecutar script de página:", scriptErr);
          }
        }
      } finally {
        isNavigatingSpa = false;
      }

      // 8. Asegurar persistencia de traducción si hay idioma activo en cookie
      try {
        const activeLang = window.translator ? window.translator.getSavedLanguage() : null;
        if (window.translator && activeLang && activeLang !== "original" && activeLang !== "es") {
          window.translator.translatePage(activeLang);
        }
      } catch (postTransErr) {}

      // 9. Manejar desplazamiento a ancla o al inicio
      const parsedUrl = new URL(url, window.location.href);
      if (parsedUrl.hash) {
        const targetElement = document.querySelector(parsedUrl.hash);
        if (targetElement) {
          setTimeout(() => {
            targetElement.scrollIntoView({ behavior: "smooth" });
          }, 60);
        } else {
          window.scrollTo(0, 0);
        }
      } else {
        window.scrollTo(0, 0);
      }

      // 10. Actualizar clase active en navegación
      updateActiveLinks(parsedUrl.pathname);

      // 11. Cerrar drawer lateral si estaba abierto
      const activeDrawer = document.getElementById("mobile-drawer");
      const activeBackdrop = document.getElementById("drawer-backdrop");
      const activeToggle = document.getElementById("menu-toggle-btn");
      if (activeDrawer) activeDrawer.classList.remove("open");
      if (activeBackdrop) activeBackdrop.classList.remove("open");
      if (activeToggle) activeToggle.classList.remove("active");
      document.body.classList.remove("drawer-open");

      // 12. Cerrar modal QR si estaba abierto
      if (window.closeQrModal) {
        window.closeQrModal();
      }

      if (window.CloudComponents) {
        if (window.CloudComponents.decorateSelects) window.CloudComponents.decorateSelects();
        if (window.CloudComponents.initQrModalEvents) window.CloudComponents.initQrModalEvents();
      }

      finishProgress();
    } catch (err) {
      if (err.name !== "AbortError") {
        console.error("[SPA Router] Fallback a navegación tradicional:", err);
        window.location.href = url;
      }
    }
  }

  // Intercepción global de clics en enlaces
  document.addEventListener("click", (e) => {
    if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.defaultPrevented) {
      return;
    }

    const anchor = e.target.closest("a");
    if (!anchor) return;

    const href = anchor.getAttribute("href");
    if (!href || href.startsWith("javascript:") || href.startsWith("mailto:") || href.startsWith("tel:")) {
      return;
    }

    if (anchor.target && anchor.target !== "_self") {
      return;
    }

    if (anchor.hasAttribute("download")) {
      return;
    }

    // Desplazamiento suave para anclas en la misma página
    if (href.startsWith("#")) {
      const targetElement = document.querySelector(href);
      const docsMain = document.querySelector(".docs-main-content");
      if (docsMain && targetElement && docsMain.contains(targetElement)) {
        e.preventDefault();
        const mainRect = docsMain.getBoundingClientRect();
        const targetRect = targetElement.getBoundingClientRect();
        const offset = targetRect.top - mainRect.top + docsMain.scrollTop - 24;
        docsMain.scrollTo({ top: Math.max(0, offset), behavior: "smooth" });
        window.history.pushState(null, "", href);
        return;
      }
      if (targetElement) {
        e.preventDefault();
        targetElement.scrollIntoView({ behavior: "smooth" });
        window.history.pushState(null, "", href);
      }
      return;
    }

    // Resolver URL destino
    const targetUrl = new URL(anchor.href, window.location.href);

    // Nunca interceptar endpoints de la API REST o descargas multimedia
    if (targetUrl.pathname.startsWith("/api/") || targetUrl.pathname === "/api") {
      return;
    }

    // Verificar mismo origen (evitar interceptar links externos)
    if (targetUrl.origin !== window.location.origin) {
      return;
    }

    // Si es la misma página exacta
    if (targetUrl.pathname === window.location.pathname && targetUrl.search === window.location.search) {
      if (targetUrl.hash) {
        const targetElement = document.querySelector(targetUrl.hash);
        if (targetElement) {
          e.preventDefault();
          targetElement.scrollIntoView({ behavior: "smooth" });
          window.history.pushState(null, "", targetUrl.hash);
          return;
        }
      } else {
        e.preventDefault();
        window.scrollTo({ top: 0, behavior: "smooth" });
        return;
      }
    }

    // Navegar fluidamente sin recargar la página
    e.preventDefault();
    navigate(targetUrl.href, true);
  });

  // Manejar navegación con botones Atrás y Adelante
  window.addEventListener("popstate", () => {
    navigate(window.location.href, false);
  });

  // Actualizar estado 'active' en cabecera, menú lateral y pie de página
  function updateActiveLinks(pathname) {
    try {
      const currentPath = pathname || window.location.pathname;
      const allLinks = document.querySelectorAll(".main-menu a, .drawer-menu a, .footer-col a, .footer-links a");
      allLinks.forEach(link => {
        const linkHref = link.getAttribute("href");
        if (!linkHref || linkHref.startsWith("#") || linkHref.startsWith("http://") || linkHref.startsWith("https://")) return;
        try {
          const linkPath = new URL(linkHref, window.location.href).pathname;
          const isMatch = (linkPath === currentPath) || 
                          ((currentPath === "/" || currentPath === "/index.html") && (linkPath === "/" || linkPath === "/index.html"));
          if (isMatch) {
            link.classList.add("active");
          } else {
            link.classList.remove("active");
          }
        } catch (e) {}
      });
    } catch (e) {}
  }

  // Inicializar estado activo al cargar el documento
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => updateActiveLinks(window.location.pathname), { once: true });
  } else {
    updateActiveLinks(window.location.pathname);
  }

  // Exponer API
  window.SPARouter = {
    navigate: navigate,
    updateActiveLinks: updateActiveLinks
  };
})();
