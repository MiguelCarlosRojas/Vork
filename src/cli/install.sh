#!/usr/bin/env bash
# ==============================================================================
# Vork CLI - Universal Installer for macOS and Linux v1.0.3
# Despliega el motor completo de Vork CLI consumiendo src/cli/src
# Uso local:  ./install.sh
# Uso remoto: curl -fsSL https://vork-st1k.onrender.com/cli/install.sh | bash
# ==============================================================================

set -e

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;2;56;189;248m'
CORAL='\033[38;2;255;107;74m'
GREEN='\033[38;2;74;222;128m'
YELLOW='\033[38;2;234;179;8m'
PURPLE='\033[38;2;168;85;247m'
WHITE='\033[97m'
DIM='\033[2m'

USER_NAME="$(whoami 2>/dev/null || echo "User")"
HOST_NAME="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "Host")"
IDENT_LABEL="${USER_NAME}@${HOST_NAME}"
if [ ${#IDENT_LABEL} -gt 24 ]; then
    IDENT_LABEL="${IDENT_LABEL:0:21}..."
fi

CURRENT_DIR="$PWD"
USER_HOME="${HOME:-~}"
SHORT_DIR="${CURRENT_DIR/#$USER_HOME/\~}"
if [ ${#SHORT_DIR} -gt 38 ]; then
    SHORT_DIR=".../$(basename "$CURRENT_DIR")"
fi

echo ""
printf "  ${BOLD}VORK CLI v1.0.3${RESET}                            ${CORAL}██     ██${RESET}\n"
printf "  ${BOLD}Vork 3.2${RESET} ${PURPLE}(Expert)${RESET}                          ${CORAL}▀██   ██▀${RESET}\n"
printf "  ${WHITE}%-24s${RESET} ${CYAN}(Vork AI)${RESET}       ${CORAL}▀██ ██▀${RESET}\n" "$IDENT_LABEL"
printf "  ${CORAL}❯${RESET} ${WHITE}%-38s${RESET}   ${CORAL}▀███▀${RESET}\n" "$SHORT_DIR"
echo ""

# 1. Detección automática del Sistema Operativo y Arquitectura
OS_TYPE="$(uname -s)"
ARCH_TYPE="$(uname -m)"

case "$OS_TYPE" in
    Darwin) PLATFORM="macOS" ;;
    Linux)  PLATFORM="Linux" ;;
    *)      PLATFORM="$OS_TYPE" ;;
esac

echo -e "  ${CYAN}==>${RESET} Entorno detectado: ${BOLD}${PLATFORM}${RESET} (${ARCH_TYPE})"

# 2. Directorios globales de instalación
INSTALL_DIR="$HOME/.vork"
BIN_DIR="$INSTALL_DIR/bin"
ENGINE_DIR="$INSTALL_DIR/engine"

mkdir -p "$BIN_DIR"
mkdir -p "$ENGINE_DIR"

# 3. Localizar el directorio fuente src/cli/src
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
SRC_DIR=""

for CANDIDATE in \
    "$SCRIPT_DIR/src" \
    "$SCRIPT_DIR/src/cli/src" \
    "$CURRENT_DIR/src/cli/src" \
    "$CURRENT_DIR/src"
do
    if [ -f "$CANDIDATE/core/config.ps1" ] || [ -f "$CANDIDATE/index.ts" ]; then
        SRC_DIR="$(cd "$CANDIDATE" && pwd)"
        break
    fi
done

CLI_ROOT=""
if [ -n "$SRC_DIR" ]; then
    CLI_ROOT="$(cd "$SRC_DIR/.." && pwd)"
fi

if [ -n "$SRC_DIR" ] && [ -d "$SRC_DIR" ]; then
    echo -e "  ${CYAN}==>${RESET} Consumiendo código fuente local desde: ${BOLD}${SRC_DIR}${RESET}"

    # Compilar y sincronizar motor TypeScript
    LOCAL_DIST="$CLI_ROOT/dist"
    ENGINE_DIST="$ENGINE_DIR/dist"

    if [ ! -f "$LOCAL_DIST/index.js" ] && command -v npm >/dev/null 2>&1; then
        echo -e "  ${CYAN}==>${RESET} Compilando motor TypeScript..."
        (cd "$CLI_ROOT" && npm run build) >/dev/null 2>&1 || true
    fi

    if [ -f "$LOCAL_DIST/index.js" ]; then
        echo -e "  ${CYAN}==>${RESET} Sincronizando distribución compilada a ${ENGINE_DIST}..."
        mkdir -p "$ENGINE_DIST"
        cp -R "$LOCAL_DIST"/* "$ENGINE_DIST"/
        echo -e "  ${GREEN}[OK]${RESET} Motor TypeScript sincronizado con éxito."
    fi

    if [ -f "$CLI_ROOT/package.json" ]; then
        cp "$CLI_ROOT/package.json" "$ENGINE_DIR/package.json"
    fi

    if [ -d "$CLI_ROOT/node_modules" ]; then
        if [ ! -d "$ENGINE_DIR/node_modules" ]; then
            echo -e "  ${CYAN}==>${RESET} Vinculando dependencias de Node.js..."
            ln -sfn "$CLI_ROOT/node_modules" "$ENGINE_DIR/node_modules" 2>/dev/null || cp -R "$CLI_ROOT/node_modules" "$ENGINE_DIR/"
        fi
    fi

    # Si pwsh está instalado, ensamblar vork.ps1 en ~/.vork/bin
    if command -v pwsh >/dev/null 2>&1; then
        OUT_PS1="$BIN_DIR/vork.ps1"
        MODULES=(
            "core/config.ps1"
            "ui/toolkit.ps1"
            "ui/banner.ps1"
            "ui/cards.ps1"
            "ui/help.ps1"
            "pillars/p01_translate.ps1"
            "pillars/p02_tts.ps1"
            "pillars/p03_clone.ps1"
            "pillars/p04_media.ps1"
            "pillars/p05_separate.ps1"
            "pillars/p06_image.ps1"
            "pillars/p07_remove_bg.ps1"
            "pillars/p08_generate_image.ps1"
            "pillars/p09_agents.ps1"
            "pillars/commands.ps1"
            "pillars/system.ps1"
            "core/updater.ps1"
            "core/router.ps1"
        )
        rm -f "$OUT_PS1"
        for MOD in "${MODULES[@]}"; do
            MOD_FILE="$SRC_DIR/$MOD"
            if [ -f "$MOD_FILE" ]; then
                echo -e "\n# ========================================================\n# MODULE: $MOD\n# ========================================================" >> "$OUT_PS1"
                cat "$MOD_FILE" >> "$OUT_PS1"
            fi
        done
        echo -e "  ${GREEN}[OK]${RESET} Lanzador PowerShell Core ensamblado en ${OUT_PS1}"
    fi

else
    echo -e "  ${CYAN}==>${RESET} Descargando componentes desde el repositorio oficial..."
    API_BASE="${VORK_API:-https://vork-st1k.onrender.com}"
    curl -fsSL "$API_BASE/cli/vork.ps1" -o "$BIN_DIR/vork.ps1" 2>/dev/null || true
fi

# 4. Generar lanzador universal bin/vork
cat << 'LAUNCHER' > "$BIN_DIR/vork"
#!/usr/bin/env bash
# Vork CLI Launcher (macOS & Linux) v1.0.3
VORK_DIR="$HOME/.vork"
ENGINE_INDEX="$VORK_DIR/engine/dist/index.js"

if [ -f "$ENGINE_INDEX" ] && command -v node >/dev/null 2>&1; then
    exec node "$ENGINE_INDEX" "$@"
fi

if [ -f "$VORK_DIR/bin/vork.ps1" ] && command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$VORK_DIR/bin/vork.ps1" "$@"
fi

echo "[ERROR] Se requiere Node.js (>=18) o PowerShell Core (pwsh) para ejecutar Vork CLI."
exit 1
LAUNCHER

chmod +x "$BIN_DIR/vork"
ln -sf "$BIN_DIR/vork" "$BIN_DIR/vk"
ln -sf "$BIN_DIR/vork" "$BIN_DIR/vork-cli"

# 5. Configurar PATH en la configuración de la terminal
SHELL_NAME="$(basename "${SHELL:-bash}")"
EXPORT_LINE="export PATH=\"\$HOME/.vork/bin:\$PATH\""

case "$SHELL_NAME" in
    zsh)   RC_FILE="$HOME/.zshrc" ;;
    bash)  RC_FILE="$([ "$OS_TYPE" = "Darwin" ] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc")" ;;
    *)     RC_FILE="$HOME/.profile" ;;
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
echo -e "  ${GREEN}${BOLD}[OK] Vork CLI v1.0.3 se instaló correctamente en ${PLATFORM}!${RESET}"
echo ""
echo -e "  ${BOLD}Comandos globales disponibles:${RESET}"
echo -e "    ${YELLOW}vork${RESET}                 -> Abre la interfaz interactiva Vork AI"
echo -e "    ${YELLOW}vork run <tarea>${RESET}     -> Modo agente autónomo con ejecución y herramientas"
echo -e "    ${YELLOW}vork doctor${RESET}          -> Diagnóstico del sistema y proveedores gratuitos"
echo -e "    ${YELLOW}vork models${RESET}          -> Estado de modelos disponibles (+20 proveedores)"
echo -e "    ${YELLOW}vork translate${RESET}       -> Pilar 01: Traductor en la Nube"
echo -e "    ${YELLOW}vork agents${RESET}          -> Pilar 09: Agentes Autónomos"
echo ""
echo -e "  ${DIM}Alias disponibles: vork, vk, vork-cli${RESET}"
echo ""
