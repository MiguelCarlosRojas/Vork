const fs = require('fs');
const path = require('path');

const cliDir = path.resolve(__dirname, '..');
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
  'pillars/p07_image.ps1',
  'pillars/p08_remove_bg.ps1',
  'pillars/p09_agents.ps1',
  'pillars/p10_generate_image.ps1',
  'pillars/commands.ps1',
  'pillars/system.ps1',
  'core/updater.ps1',
  'core/router.ps1'
];

let fullCode = '\uFEFF'; // UTF-8 BOM
for (const rel of files) {
  const p = path.join(cliDir, rel);
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

const targetPath = path.join(cliDir, 'vork.ps1');
fs.writeFileSync(targetPath, fullCode, 'utf8');
console.log('src/cli/vork.ps1 assembled successfully. Size:', fullCode.length);

const userHome = process.env.USERPROFILE || process.env.HOME;
const globalBin = path.join(userHome, '.vork', 'bin', 'vork.ps1');
if (fs.existsSync(path.dirname(globalBin))) {
  fs.writeFileSync(globalBin, fullCode, 'utf8');
  console.log('Synced to global CLI:', globalBin);
}
