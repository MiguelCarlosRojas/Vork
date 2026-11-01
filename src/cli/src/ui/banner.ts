import os from "node:os";
import path from "node:path";
import stringWidth from "string-width";

const CORAL = "\x1b[38;2;255;107;74m";
const WHITE_BOLD = "\x1b[97;1m";
const WHITE = "\x1b[97m";
const CYAN = "\x1b[38;2;56;189;248m";
const YELLOW = "\x1b[38;2;234;179;8m";
const PURPLE = "\x1b[38;2;168;85;247m";
const GREEN = "\x1b[38;2;74;222;128m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

export interface VorkBannerOptions {
  version?: string;
  model?: string;
  tier?: string;
  width?: number;
}

export function formatSmartPath(currPath: string, width = 80): string {
  const home = os.homedir();
  let normalized = currPath.split(path.sep).join("/");
  const homeNorm = home.split(path.sep).join("/");

  if (normalized.startsWith(homeNorm)) {
    normalized = "~" + normalized.slice(homeNorm.length);
  }

  const maxBudget = Math.max(20, Math.min(38, width - 22));
  if (normalized.length > maxBudget) {
    if (normalized.startsWith("~/")) {
      const parts = normalized.slice(2).split("/");
      if (parts.length >= 3) {
        normalized = "~../" + parts[parts.length - 2] + "/" + parts[parts.length - 1];
      } else if (parts.length === 2) {
        normalized = "~../" + parts[1];
      }
    }
    if (normalized.length > maxBudget) {
      normalized = "..." + normalized.slice(normalized.length - (maxBudget - 3));
    }
  }
  return normalized;
}

export function getTierColor(tier: string): string {
  const t = (tier || "expert").toLowerCase();
  switch (t) {
    case "low":
      return GREEN;
    case "medium":
      return YELLOW;
    case "high":
      return CORAL;
    case "expert":
      return PURPLE;
    default:
      return CYAN;
  }
}

/**
 * Imprime el banner visual oficial y exacto de Vork CLI
 */
export function printVorkBanner(options: VorkBannerOptions = {}) {
  const width = options.width || (process.stdout.columns ? Math.max(20, process.stdout.columns - 1) : 80);
  const version = options.version || "v1.0.3";
  const modelName = options.model || "Vork 3.2";
  const tierName = options.tier || "Expert";
  const tierColor = getTierColor(tierName);

  let devIdentity = (process.env.COMPUTERNAME || os.hostname() || "PC").trim();
  const maxDevBudget = Math.max(12, Math.min(28, width - 25));
  if (devIdentity.length > maxDevBudget) {
    devIdentity = devIdentity.slice(0, maxDevBudget - 3) + "...";
  }
  const userMachineLabel = `${devIdentity} (Vork AI)`;

  const pathShown = formatSmartPath(process.cwd(), width);

  // Logo V estilizado a escala simétrica (4 líneas, 9 columnas exactas)
  const vRows = [
    "██     ██",
    "▀██   ██▀",
    " ▀██ ██▀ ",
    "  ▀███▀  "
  ];
  const chevron = "❯";

  console.log("");

  if (width >= 46) {
    const vis0 = `VORK CLI ${version}`.length;
    const vis1 = `${modelName} (${tierName})`.length;
    const vis2 = userMachineLabel.length;
    const vis3 = 2 + pathShown.length;

    const maxLeftNeeded = Math.max(Math.max(Math.max(vis0, vis1), vis2), vis3);
    const targetLogoCol = Math.min(Math.max(18, width - 11), maxLeftNeeded + 3);

    // Fila 0
    const left0 = `${WHITE_BOLD}VORK CLI${RESET} ${WHITE}${version}${RESET}`;
    const pad0 = " ".repeat(Math.max(2, targetLogoCol - vis0));
    console.log(`  ${left0}${pad0}${CORAL}${vRows[0]}${RESET}`);

    // Fila 1
    const left1 = `${WHITE_BOLD}${modelName}${RESET} ${tierColor}(${tierName})${RESET}`;
    const pad1 = " ".repeat(Math.max(2, targetLogoCol - vis1));
    console.log(`  ${left1}${pad1}${CORAL}${vRows[1]}${RESET}`);

    // Fila 2
    const left2 = `${WHITE}${devIdentity}${RESET} ${CYAN}(Vork AI)${RESET}`;
    const pad2 = " ".repeat(Math.max(2, targetLogoCol - vis2));
    console.log(`  ${left2}${pad2}${CORAL}${vRows[2]}${RESET}`);

    // Fila 3
    const left3 = `${CORAL}${chevron}${RESET} ${WHITE}${pathShown}${RESET}`;
    const pad3 = " ".repeat(Math.max(2, targetLogoCol - vis3));
    console.log(`  ${left3}${pad3}${CORAL}${vRows[3]}${RESET}`);
  } else {
    console.log(`  ${WHITE_BOLD}VORK CLI${RESET} ${WHITE}${version}${RESET}`);
    console.log(`  ${WHITE_BOLD}${modelName}${RESET} ${tierColor}(${tierName})${RESET}`);
    console.log(`  ${WHITE}${devIdentity}${RESET} ${CYAN}(Vork AI)${RESET}`);
    console.log(`  ${CORAL}${chevron}${RESET} ${WHITE}${pathShown}${RESET}`);
  }

  console.log("");
}

/**
 * Renderiza el marco de caja exacto de entrada para Vork CLI
 */
export function formatVorkPromptFrame(options: {
  model?: string;
  tier?: string;
  placeholder?: string;
  width?: number;
}): { top: string; content: string; bottom: string } {
  const width = options.width || (process.stdout.columns ? Math.max(20, process.stdout.columns) : 80);
  const model = options.model || "Vork 3.2";
  const tier = options.tier || "Expert";
  const tierColor = getTierColor(tier);
  const placeholder = options.placeholder || "Escribe tu mensaje o usa /comando";

  const statusText = `${tierColor}●${RESET} ${WHITE_BOLD}${model}${RESET} ${WHITE}·${RESET} ${tierColor}${tier}${RESET}`;
  const statusPlain = `● ${model} · ${tier}`;
  const statusLen = stringWidth(statusPlain);

  // Top border: ╭─────...───── ● Vork 3.2 · Expert ─╮
  const topDashes = Math.max(4, width - statusLen - 7);
  const top = `${WHITE}╭${"─".repeat(topDashes)} ${statusText} ─╮${RESET}`;

  // Content line: │ ❯ Escribe tu mensaje o usa /comando          │
  const promptInner = `${CORAL}❯${RESET} ${DIM}${placeholder}${RESET}`;
  const promptInnerPlain = `❯ ${placeholder}`;
  const innerPad = Math.max(1, width - stringWidth(promptInnerPlain) - 4);
  const content = `${WHITE}│${RESET} ${promptInner}${" ".repeat(innerPad)}${WHITE}│${RESET}`;

  // Bottom border: ╰─ ? for shortcuts · ctrl+c: salir ───────...───╯
  const hintsPlain = "? for shortcuts · ctrl+c: salir";
  const hintsFormatted = `${WHITE}?${RESET} ${DIM}for shortcuts${RESET} ${WHITE}·${RESET} ${WHITE}ctrl+c:${RESET} ${DIM}salir${RESET}`;
  const bottomDashes = Math.max(4, width - stringWidth(hintsPlain) - 7);
  const bottom = `${WHITE}╰─ ${hintsFormatted} ${"─".repeat(bottomDashes)}╯${RESET}`;

  return { top, content, bottom };
}

export function printVorkPromptFrame(options: {
  model?: string;
  tier?: string;
  placeholder?: string;
  width?: number;
}) {
  const frame = formatVorkPromptFrame(options);
  console.log(frame.top);
  console.log(frame.content);
  console.log(frame.bottom);
}
