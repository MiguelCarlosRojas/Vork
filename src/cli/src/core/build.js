import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const srcDir = path.resolve(__dirname, '..');
const cliDir = path.resolve(__dirname, '../..');

const files = [
  'core/config.ps1',
  'ui/toolkit.ps1',
  'ui/banner.ps1',
  'ui/cards.ps1',
  'ui/help.ps1',
  'pillars/p01_translate.ps1',
  'pillars/p02_tts.ps1',
  'pillars/p03_clone.ps1',
  'pillars/p04_media.ps1',
  'pillars/p05_separate.ps1',
  'pillars/p06_image.ps1',
  'pillars/p07_remove_bg.ps1',
  'pillars/p08_generate_image.ps1',
  'pillars/p09_agents.ps1',
  'pillars/commands.ps1',
  'pillars/system.ps1',
  'core/updater.ps1',
  'core/router.ps1'
];

let fullCode = '\uFEFF'; // UTF-8 BOM
for (const rel of files) {
  const p = path.join(srcDir, rel);
  if (!fs.existsSync(p)) {
    console.error('File not found:', p);
    process.exit(1);
  }
  let content = fs.readFileSync(p, 'utf8');
  if (content.charCodeAt(0) === 0xFEFF) {
    content = content.slice(1);
  }
  fullCode += `\r\n# ========================================================\r\n# MODULE: ${rel}\r\n# ========================================================\r\n` + content + '\r\n';
}

// Ensamblar directamente a la ubicación global si existe o bajo demanda
const userHome = process.env.USERPROFILE || process.env.HOME;
const globalBin = path.join(userHome, '.vork', 'bin');
if (!fs.existsSync(globalBin)) {
  fs.mkdirSync(globalBin, { recursive: true });
}
const globalPs1 = path.join(globalBin, 'vork.ps1');
fs.writeFileSync(globalPs1, fullCode, 'utf8');
console.log('Vork CLI PowerShell launcher assembled directly in:', globalPs1);

const globalEngine = path.join(userHome, '.vork', 'engine');
const localDist = path.join(cliDir, 'dist');
if (fs.existsSync(localDist)) {
  const engineDist = path.join(globalEngine, 'dist');
  if (!fs.existsSync(engineDist)) fs.mkdirSync(engineDist, { recursive: true });
  fs.cpSync(localDist, engineDist, { recursive: true });
  console.log('Synced engine dist to global:', engineDist);
}
