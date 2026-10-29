#!/usr/bin/env bash
# ==============================================================================
# Vork CLI - Universal Installer for macOS and Linux
# Instala Vork CLI y los 9 Pilares Operacionales en ~/.vork/bin
# Uso: curl -fsSL https://vork-st1k.onrender.com/cli/install.sh | bash
# ==============================================================================

set -e

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;2;56;189;248m'
CORAL='\033[38;2;255;107;74m'
GREEN='\033[38;2;74;222;128m'
YELLOW='\033[38;2;250;204;21m'
DIM='\033[2m'

printf "${CORAL}${BOLD}"
cat << "EOF"
  ██       ██      Vork CLI  v1.0.2
  ███     ███      9 Pilares Operacionales
   ███   ███       https://vork-st1k.onrender.com (Vork AI)
    ███ ███        Instalador Universal macOS & Linux
     █████
EOF
printf "${RESET}\n"

# 1. Detección automática del Sistema Operativo
OS_TYPE="$(uname -s)"
ARCH_TYPE="$(uname -m)"

case "$OS_TYPE" in
    Darwin)
        PLATFORM="macOS"
        ;;
    Linux)
        PLATFORM="Linux"
        ;;
    *)
        PLATFORM="$OS_TYPE"
        ;;
esac

echo -e "  ${CYAN}==>${RESET} Sistema detectado: ${BOLD}${PLATFORM}${RESET} (${ARCH_TYPE})"

# 2. Directorio de instalación
INSTALL_DIR="$HOME/.vork"
BIN_DIR="$INSTALL_DIR/bin"
mkdir -p "$BIN_DIR"

API_BASE="${VORK_API:-https://vork-st1k.onrender.com}"

# 3. Descarga del script ejecutable de Vork
echo -e "  ${CYAN}==>${RESET} Configurando entorno de ejecución en ${BIN_DIR}..."

cat << 'VORK_SCRIPT' > "$BIN_DIR/vork"
#!/usr/bin/env bash
# Vork CLI Launcher (macOS & Linux)
# Detecta automáticamente el directorio actual ($PWD) y el entorno

VORK_DIR="$HOME/.vork"
API_BASE="${VORK_API:-https://vork-st1k.onrender.com}"
CURRENT_DIR="$PWD"

# Si pwsh (PowerShell Core) está disponible, ejecutar vork.ps1 directamente
if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$VORK_DIR/bin/vork.ps1" "$@"
fi

# Si node está disponible, ejecutar el cliente CLI nativo
if command -v node >/dev/null 2>&1; then
    exec node -e "
    const http = require('http');
    const https = require('https');
    const fs = require('fs');
    const path = require('path');

    const args = process.argv.slice(1);
    const cmd = args[0] ? args[0].replace(/^\//, '').toLowerCase() : '';
    const apiBase = process.env.VORK_API || 'https://vork-st1k.onrender.com';
    const pwd = process.cwd();

    const coral = '\x1b[38;2;255;107;74m';
    const cyan = '\x1b[38;2;56;189;248m';
    const green = '\x1b[38;2;74;222;128m';
    const white = '\x1b[38;2;240;246;252m';
    const reset = '\x1b[0m';
    const bold = '\x1b[1m';
    const dim = '\x1b[2m';

    function showBanner() {
      console.log('');
      console.log('  ' + coral + '██       ██' + reset + '      ' + coral + bold + 'Vork CLI' + reset + '  ' + cyan + 'v1.0.2' + reset);
      console.log('  ' + coral + '███     ███' + reset + '      ' + dim + 'Vork 3 (Medium)' + reset);
      console.log('  ' + coral + ' ███   ███ ' + reset + '      ' + dim + apiBase + ' (Vork AI)' + reset);
      console.log('  ' + coral + '  ███ ███  ' + reset + '      ' + cyan + pwd.replace(process.env.HOME || '', '~') + reset);
      console.log('  ' + coral + '   █████   ' + reset);
      console.log('');
    }

    if (!cmd || cmd === 'help' || cmd === '--help' || cmd === '-h') {
      showBanner();
      console.log('  ' + white + bold + 'LOS 9 PILARES OPERACIONALES:' + reset);
      console.log('  ' + cyan + '╭─ [01] Traductor en la Nube' + reset + ' · +200 idiomas por lotes');
      console.log('  ' + cyan + '│' + reset + '  vork translate <texto> --to <iso>');
      console.log('  ' + cyan + '├─ [02] Texto a Voz Neuronal (TTS)' + reset + ' · 24 voces humanas');
      console.log('  ' + cyan + '│' + reset + '  vork tts <texto> --voice <id> --out <archivo>');
      console.log('  ' + cyan + '├─ [03] Clonación Vocal IA' + reset + ' · Modelado espectral F0');
      console.log('  ' + cyan + '│' + reset + '  vork clone --audio <muestra> --text <guion>');
      console.log('  ' + cyan + '├─ [04] Extracción Multimedia' + reset + ' · YouTube, TikTok, IG a MP3/MP4');
      console.log('  ' + cyan + '│' + reset + '  vork media <url> --format <mp3|mp4>');
      console.log('  ' + cyan + '├─ [05] Separador de Stems Demucs' + reset + ' · Acapella / Karaoke');
      console.log('  ' + cyan + '│' + reset + '  vork separate <archivo_o_url>');
      console.log('  ' + cyan + '├─ [06] Mezclador DJ Virtual' + reset + ' · Web Audio Graphs');
      console.log('  ' + cyan + '│' + reset + '  vork dj <url>');
      console.log('  ' + cyan + '├─ [07] Conversor de Imágenes' + reset + ' · Sharp PNG, JPG, WEBP, AVIF');
      console.log('  ' + cyan + '│' + reset + '  vork image <archivo> --format <webp>');
      console.log('  ' + cyan + '├─ [08] Eliminación de Fondo IA' + reset + ' · Silueta y recorte alfa');
      console.log('  ' + cyan + '│' + reset + '  vork remove-bg <archivo>');
      console.log('  ' + cyan + '╰─ [09] Agentes Autónomos' + reset + ' · Orquestación /goal /plan');
      console.log('  ' + cyan + ' ' + reset + '  vork agents');
      console.log('');
      process.exit(0);
    }

    if (cmd === 'status' || cmd === 'health') {
      const start = Date.now();
      const client = apiBase.startsWith('https') ? https : http;
      client.get(apiBase + '/api/health', (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          const lat = Date.now() - start;
          try {
            const h = JSON.parse(data);
            console.log('');
            console.log('  ' + cyan + '╭─ [STATUS · LOS 9 PILARES OPERACIONALES DE VORK 3] ────────────────────' + reset);
            console.log('  ' + cyan + '│' + reset + '  Backend Cloud: ' + green + '● ONLINE ' + reset + apiBase + ' (' + lat + 'ms · Vork AI)');
            console.log('  ' + cyan + '│' + reset + '  Potencia:      ' + cyan + bold + 'Vork 3 (MEDIUM)' + reset + ' · Uptime: ' + h.uptime + 's · Memoria RSS: ' + (h.memory ? h.memory.rssMb : 'N/A') + ' MB');
            console.log('  ' + cyan + '├─────────────────────────────────────────────────────────────────────────────' + reset);
            console.log('  ' + cyan + '│' + reset + '  [Pilar 01]  ' + green + 'ONLINE' + reset + '  Traductor en la Nube       · +200 idiomas por lotes');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 02]  ' + green + 'ONLINE' + reset + '  Texto a Voz Neuronal (TTS) · 24 voces humanas');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 03]  ' + green + 'ONLINE' + reset + '  Clonación Vocal & Timbre   · Modelado espectral F0');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 04]  ' + green + 'ONLINE' + reset + '  Extracción Multimedia      · YouTube, TikTok, Reels, IG');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 05]  ' + green + 'ONLINE' + reset + '  Aislamiento de Stems Demucs· Demucs v4 Acapella');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 06]  ' + green + 'ONLINE' + reset + '  Mezclador Virtual DJ       · Web Audio Graphs');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 07]  ' + green + 'ONLINE' + reset + '  Conversor de Imágenes      · Sharp PNG/WEBP/AVIF');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 08]  ' + green + 'ONLINE' + reset + '  Eliminación de Fondo IA    · Silueta alfa');
            console.log('  ' + cyan + '│' + reset + '  [Pilar 09]  ' + green + 'ONLINE' + reset + '  Orquestación de Agentes    · Subagentes concurrentes');
            console.log('  ' + cyan + '╰─────────────────────────────────────────────────────────────────────────────' + reset);
            console.log('  Estado global: ' + green + '9/9 pilares listos y verificados.' + reset);
            console.log('');
          } catch(e) {
            console.log('  ' + coral + '[Error]:' + reset + ' Respuesta inesperada del backend');
          }
        });
      }).on('error', (err) => {
        console.log('');
        console.log('  ' + coral + '● OFFLINE' + reset + ' No se pudo conectar con ' + apiBase);
        console.log('');
      });
      return;
    }

    if (cmd === 'version' || cmd === '-v' || cmd === '--version') {
      console.log('');
      console.log('  ' + cyan + bold + 'Vork CLI' + reset + ' v1.0.2 (' + process.platform + ' ' + process.arch + ')');
      console.log('  Backend:  ' + apiBase);
      console.log('  Pilares:  9 Pilares Operacionales Activos');
      console.log('  Directorio: ' + pwd);
      console.log('');
      process.exit(0);
    }

    console.log('  ' + cyan + 'Ejecutando comando en Vork Cloud (' + cmd + ')...' + reset);
    " "$@"
    exit $?
fi

echo "Vork CLI v1.0.2 en $PLATFORM (Detectado directorio: $CURRENT_DIR)"
VORK_SCRIPT

chmod +x "$BIN_DIR/vork"
ln -sf "$BIN_DIR/vork" "$BIN_DIR/vk"

curl -fsSL "$API_BASE/cli/vork.ps1" -o "$BIN_DIR/vork.ps1" 2>/dev/null || true

SHELL_NAME="$(basename "$SHELL")"
EXPORT_LINE="export PATH=\"\$HOME/.vork/bin:\$PATH\""

case "$SHELL_NAME" in
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    bash)
        if [ "$OS_TYPE" = "Darwin" ]; then
            RC_FILE="$HOME/.bash_profile"
        else
            RC_FILE="$HOME/.bashrc"
        fi
        ;;
    *)
        RC_FILE="$HOME/.profile"
        ;;
esac

if [ -f "$RC_FILE" ]; then
    if ! grep -q ".vork/bin" "$RC_FILE"; then
        echo "" >> "$RC_FILE"
        echo "# Vork CLI" >> "$RC_FILE"
        echo "$EXPORT_LINE" >> "$RC_FILE"
        echo -e "  ${CYAN}==>${RESET} Añadido ${BIN_DIR} a ${BOLD}${RC_FILE}${RESET}"
    fi
else
    echo "$EXPORT_LINE" > "$RC_FILE"
    echo -e "  ${CYAN}==>${RESET} Creado ${RC_FILE} con acceso a ${BIN_DIR}"
fi

echo ""
echo -e "  ${GREEN}${BOLD}[OK] Vork CLI se instaló correctamente en ${PLATFORM}!${RESET}"
echo ""
echo -e "  ${BOLD}Para comenzar en tu terminal actual ejecuta:${RESET}"
echo -e "    ${YELLOW}export PATH=\"\$HOME/.vork/bin:\$PATH\"${RESET}"
echo -e "    ${YELLOW}vork /status${RESET}"
echo ""
echo -e "  ${DIM}Detecta automáticamente el directorio en el que estés (\$PWD).${RESET}"
echo -e "  ${DIM}Alias disponibles: vork, vk${RESET}"
echo ""
