import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const home = os.homedir();
const iconPath = path.join(home, '.vork', 'vork.png').replace(/\\/g, '/');
const localAppData = process.env.LOCALAPPDATA;

// 1. Windows Terminal Integration
if (localAppData) {
  const packagesDir = path.join(localAppData, 'Packages');
  if (fs.existsSync(packagesDir)) {
    const dirs = fs.readdirSync(packagesDir).filter(d => d.startsWith('Microsoft.WindowsTerminal'));
    dirs.forEach(d => {
      const sPath = path.join(packagesDir, d, 'LocalState', 'settings.json');
      if (fs.existsSync(sPath)) {
        try {
          const content = fs.readFileSync(sPath, 'utf8');
          const cleanContent = content.replace(/\/\/.*$/gm, '').replace(/\/\*[\s\S]*?\*\//g, '');
          const settings = JSON.parse(cleanContent);
          let modified = false;

          if (settings.profiles && settings.profiles.list) {
            settings.profiles.list.forEach(p => {
              if (p.name && (p.name.toLowerCase().includes('vork') || p.commandline && p.commandline.toLowerCase().includes('vork'))) {
                p.icon = iconPath;
                modified = true;
              }
            });

            if (!modified) {
              const defaultGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}";
              settings.profiles.list.push({
                guid: "{b0d5c4a1-8d2e-4b6a-9f1c-7e3a2b1c0d9e}",
                name: "Vork CLI",
                commandline: "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command vork",
                icon: iconPath,
                startingDirectory: "%USERPROFILE%",
                hidden: false
              });
              modified = true;
            }
          }

          if (modified) {
            fs.writeFileSync(sPath, JSON.stringify(settings, null, 4), 'utf8');
            console.log(`[OK] Icono vinculado en Windows Terminal (${d})`);
          }
        } catch (e) {
          // Parsing failure
        }
      }
    });
  }
}
