/**
 * cliController.js
 * Controlador HTTP para Vork CLI (Entorno de Terminal & Agentes Autónomos)
 * Provee metadatos, especificaciones y entrega de scripts de instalación de terminal desde el backend.
 */

const path = require("path");
const fs = require("fs");

const CLI_DIR = path.join(__dirname, "..", "cli");

/**
 * Ensambla de forma dinamica y modular los componentes de Vork CLI
 * (core, ui y pillars) en un script unico autocontenido con UTF-8 BOM.
 */
function assembleVorkScript() {
  const parts = [];
  const readPart = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "").trim();

  // 1. Core Config
  const configFile = path.join(CLI_DIR, "core", "config.ps1");
  if (fs.existsSync(configFile)) {
    parts.push(readPart(configFile));
  }

  // 2. UI Modules (Toolkit, Banner, Cards, Help)
  const uiDir = path.join(CLI_DIR, "ui");
  if (fs.existsSync(uiDir)) {
    const uiFiles = ["toolkit.ps1", "banner.ps1", "cards.ps1", "help.ps1"];
    uiFiles.forEach(file => {
      const fullPath = path.join(uiDir, file);
      if (fs.existsSync(fullPath)) {
        parts.push(readPart(fullPath));
      }
    });
  }

  // 3. Core Updater
  const updaterFile = path.join(CLI_DIR, "core", "updater.ps1");
  if (fs.existsSync(updaterFile)) {
    parts.push(readPart(updaterFile));
  }

  // 4. Pillars
  const pillarsDir = path.join(CLI_DIR, "pillars");
  if (fs.existsSync(pillarsDir)) {
    const pillarFiles = fs.readdirSync(pillarsDir).filter(f => f.endsWith(".ps1")).sort();
    pillarFiles.forEach(file => {
      parts.push(readPart(path.join(pillarsDir, file)));
    });
  }

  // 5. Core Router
  const routerFile = path.join(CLI_DIR, "core", "router.ps1");
  if (fs.existsSync(routerFile)) {
    parts.push(readPart(routerFile));
  }

  // Si no hubiera modulos, usar vork.ps1 en src/cli
  if (parts.length === 0) {
    const fallbackPath = path.join(CLI_DIR, "vork.ps1");
    return fs.existsSync(fallbackPath) ? fs.readFileSync(fallbackPath, "utf8") : "";
  }

  // Ensamblar en memoria con exactamente un UTF-8 BOM para compatibilidad total con PowerShell 5.1 y 7+
  return "\uFEFF" + parts.join("\r\n\r\n# ============================================================\r\n\r\n");
}

exports.assembleVorkScript = assembleVorkScript;

/**
 * Sirve el script instalador para PowerShell (Windows)
 */
exports.getInstallPs1 = (req, res) => {
  const filePath = path.join(CLI_DIR, "install.ps1");
  if (!fs.existsSync(filePath)) {
    return res.status(404).type("text/plain").send("# Error: install.ps1 no encontrado en el backend");
  }
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=3600");
  res.sendFile(filePath);
};

/**
 * Sirve el script central ejecutable ensamblado de Vork CLI para auto-updates y ejecución (vork.ps1)
 */
exports.getVorkPs1 = (req, res) => {
  const content = assembleVorkScript();
  if (!content) {
    return res.status(404).type("text/plain").send("# Error: vork.ps1 no encontrado en el backend");
  }
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=300");
  res.send(content);
};

/**
 * Sirve el script instalador para macOS y Linux (Bash / Zsh)
 */
exports.getInstallSh = (req, res) => {
  const filePath = path.join(CLI_DIR, "install.sh");
  if (!fs.existsSync(filePath)) {
    return res.status(404).type("text/plain").send("# Error: install.sh no encontrado en el backend\n");
  }
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=3600");
  res.sendFile(filePath);
};

/**
 * Sirve el script instalador para Command Prompt (CMD)
 */
exports.getInstallCmd = (req, res) => {
  const filePath = path.join(CLI_DIR, "install.cmd");
  if (!fs.existsSync(filePath)) {
    return res.status(404).type("text/plain").send("@echo off\r\necho Error: install.cmd no encontrado en el backend\r\n");
  }
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "public, max-age=3600");
  res.sendFile(filePath);
};

/**
 * Sirve el icono oficial de Vork CLI (.ico) para ventanas y terminales
 */
exports.getVorkIco = (req, res) => {
  const filePath = path.join(__dirname, "..", "public", "img", "logo.ico");
  if (!fs.existsSync(filePath)) {
    return res.status(404).send("Icono no encontrado");
  }
  res.setHeader("Content-Type", "image/x-icon");
  res.setHeader("Cache-Control", "public, max-age=86400");
  res.sendFile(filePath);
};

exports.getCliInfo = (req, res) => {
  res.setHeader("Cache-Control", "public, max-age=3600");
  res.json({
    status: "online",
    name: "Vork CLI",
    version: "1.0.2",
    description: "Entorno centrado en la terminal para interactuar con los 10 pilares operacionales de Vork y agentes autónomos.",
    installers: {
      windows_powershell: {
        command: "irm https://vork-st1k.onrender.com/cli/install.ps1 | iex",
        url: "https://vork-st1k.onrender.com/cli/install.ps1"
      },
      windows_cmd: {
        command: "curl -fsSL https://vork-st1k.onrender.com/cli/install.cmd -o install.cmd && install.cmd && del install.cmd",
        url: "https://vork-st1k.onrender.com/cli/install.cmd"
      },
      macos: {
        command: "curl -fsSL https://vork-st1k.onrender.com/cli/install.sh | bash",
        url: "https://vork-st1k.onrender.com/cli/install.sh"
      },
      linux: {
        command: "curl -fsSL https://vork-st1k.onrender.com/cli/install.sh | bash",
        url: "https://vork-st1k.onrender.com/cli/install.sh"
      }
    },
    operationalPillars: [
      {
        pillar: 1,
        name: "Vork Traductor en la Nube",
        cliCommand: "vork translate <texto> --to <iso>",
        endpoint: "POST /api/translate",
        description: "Traducción por lotes de alta velocidad (+200 idiomas)"
      },
      {
        pillar: 2,
        name: "Vork Texto a Voz Neuronal (TTS)",
        cliCommand: "vork tts <texto> --voice <id> --out <archivo>",
        endpoint: "POST /api/tts",
        description: "Síntesis vocal fluida con 24 voces neuronales humanas"
      },
      {
        pillar: 3,
        name: "Vork Clonación de Voz con IA",
        cliCommand: "vork clone --audio <muestra> --text <guion>",
        endpoint: "POST /api/voice-clone",
        description: "Extracción fundamental F0 y recreación espectral de timbre"
      },
      {
        pillar: 4,
        name: "Vork Conversor Multimedia Universal",
        cliCommand: "vork media <url> --format <mp3|mp4>",
        endpoint: "POST /api/media/convert",
        description: "Conversión de YouTube, TikTok, Instagram, Twitter a MP3/MP4"
      },
      {
        pillar: 5,
        name: "Vork Separador de Stems",
        cliCommand: "vork separate <url_o_archivo>",
        endpoint: "POST /api/separator/process",
        description: "Extracción de stems Acapella y Karaoke con Meta Demucs v4"
      },
      {
        pillar: 6,
        name: "Vork DJ Mezclador en Vivo",
        cliCommand: "vork dj <url>",
        endpoint: "GET /dj",
        description: "Mezcla virtual con doble tornamesa, crossfader y cola interactiva"
      },
      {
        pillar: 7,
        name: "Vork Conversor de Formatos de Imagen",
        cliCommand: "vork image <archivo> --format <png|jpg|webp|ico>",
        endpoint: "POST /api/image/convert",
        description: "Conversión universal entre PNG, JPG, WEBP, GIF, BMP, TIFF e ICO"
      },
      {
        pillar: 8,
        name: "Vork Estudio y Eliminador de Fondo IA",
        cliCommand: "vork remove-bg <archivo> --mode <transparent|creative>",
        endpoint: "POST /api/image/remove-background",
        description: "Aislamiento de silueta U2-Net y composición generativa libre"
      },
      {
        pillar: 9,
        name: "Vork CLI & Agentes Autónomos",
        cliCommand: "vork agents / vork tui",
        endpoint: "GET /api/cli/info",
        description: "Orquestación por terminal de agentes y tareas paralelas"
      }
    ],
    commands: [
      { command: "vork", description: "Comando principal para invocar cualquiera de los 9 pilares" },
      { command: "vk", description: "Alias ultracorto del comando vork" },
      { command: "vork-cli", description: "Inicia la interfaz interactiva (TUI) con agentes y subagentes" }
    ],
    slashCommands: [
      // 1. Pilares Operacionales (9)
      { name: "/translate", category: "Pilares", description: "Pilar 01: Traducción neuronal por lotes en +200 idiomas" },
      { name: "/tts", category: "Pilares", description: "Pilar 02: Síntesis de voz con 24 voces neuronales humanas" },
      { name: "/clone", category: "Pilares", description: "Pilar 03: Clonación vocal IA y modelado espectral F0" },
      { name: "/media", category: "Pilares", description: "Pilar 04: Conversión multimedia de YouTube, TikTok, IG a MP3/MP4" },
      { name: "/separate", category: "Pilares", description: "Pilar 05: Aislamiento de Stems Acapella y Karaoke con Demucs v4" },
      { name: "/dj", category: "Pilares", description: "Pilar 06: Mezclador virtual en vivo con grafos Web Audio" },
      { name: "/image", category: "Pilares", description: "Pilar 07: Conversión universal PNG, JPG, WEBP, ICO, AVIF" },
      { name: "/remove-bg", category: "Pilares", description: "Pilar 08: Silueta inteligente y eliminación de fondo IA" },
      { name: "/agents", category: "Pilares", description: "Pilar 09: Orquestación de subagentes en terminal interactiva" },

      // 2. Agentes Autónomos & Planificación IA (8)
      { name: "/goal", category: "Agentes", description: "Modo autónomo continuo para resolución de tareas exhaustivas" },
      { name: "/plan", category: "Agentes", description: "Planificación guiada y desglose paso a paso de arquitectura" },
      { name: "/grill-me", category: "Agentes", description: "Entrevista interactiva para resolver decisiones de diseño" },
      { name: "/teamwork", category: "Agentes", description: "Coordinación en equipo con múltiples subagentes concurrentes" },
      { name: "/boost", category: "Agentes", description: "Razonamiento profundo con verificación multifacética" },
      { name: "/learn", category: "Agentes", description: "Persistir preferencias, reglas y aprendizajes en el sistema" },
      { name: "/browser", category: "Agentes", description: "Navegación e interacción web automatizada para pruebas" },
      { name: "/automation", category: "Agentes", description: "Diseñar y programar automatizaciones y cronjobs" },

      // 3. Contexto, Sesión & Memoria (7)
      { name: "/compact", category: "Sesión", description: "Compactar historial para liberar la ventana de contexto" },
      { name: "/clear", category: "Sesión", description: "Limpiar pantalla de terminal conservando la memoria activa" },
      { name: "/reset", category: "Sesión", description: "Reiniciar variables y contexto de la sesión actual a cero" },
      { name: "/history", category: "Sesión", description: "Explorar historial cronológico de comandos y prompts" },
      { name: "/save", category: "Sesión", description: "Guardar estado de sesión, artefactos y contexto en disco" },
      { name: "/resume", category: "Sesión", description: "Reanudar una sesión previa o restaurar estado de trabajo" },
      { name: "/undo", category: "Sesión", description: "Deshacer la última acción o modificación de código realizada" },

      // 4. Código, Auditoría & Flujo de Trabajo (4)
      { name: "/status", category: "Desarrollo", description: "Telemetría y estado operativo en vivo de los 9 pilares" },
      { name: "/review", category: "Desarrollo", description: "Auditoría de código, buenas prácticas y seguridad OWASP" },
      { name: "/bug", category: "Desarrollo", description: "Diagnóstico y depuración asistida de excepciones y trazas" },
      { name: "/refactor", category: "Desarrollo", description: "Reestructurar y optimizar código sin alterar su salida" },

      // 5. Configuración & Preferencias (6)
      { name: "/config", category: "Configuración", description: "Ajustar permisos, temas visuales y preferencias del CLI" },
      { name: "/keybindings", category: "Configuración", description: "Personalizar atajos de teclado y combinaciones" },
      { name: "/permissions", category: "Configuración", description: "Administrar permisos de ejecución de comandos y herramientas" },
      { name: "/model", category: "Configuración", description: "Configurar modelo Vork 3 y nivel de potencia (low, medium, high)" },
      { name: "/theme", category: "Configuración", description: "Alternar temas visuales (Dark, Cyberpunk, Coral, Mono)" },
      { name: "/env", category: "Configuración", description: "Consultar y gestionar variables de entorno activas" },

      // 6. Sistema, Telemetría & Utilidades (6)
      { name: "/help", category: "Sistema", description: "Manual interactivo de comandos y atajos de teclado" },
      { name: "/update", category: "Sistema", description: "Sincronizar y actualizar Vork CLI a la última versión" },
      { name: "/health", category: "Sistema", description: "Telemetría en tiempo real de los 9 pilares operacionales" },
      { name: "/ping", category: "Sistema", description: "Prueba de latencia de red hacia la nube de Vork" },
      { name: "/docs", category: "Sistema", description: "Abrir la documentación oficial de Vork en el navegador" },
      { name: "/exit", category: "Sistema", description: "Cerrar la sesión de terminal de forma segura" }
    ]
  });
};
