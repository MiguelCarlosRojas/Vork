import { createRequire } from "node:module";

// La versión sale de package.json, para que al publicar solo haya que cambiarla allí
const require = createRequire(import.meta.url);
export const VERSION: string = require("../../package.json").version;
export const REPO_URL = "https://github.com/MiguelCarlosRojas/Vork";
// Información legal de Vork CLI y atribución abierta
export const LEGAL_NOTICE = `Vork CLI ${VERSION} · © 2026 Miguel Angel Carlos Rojas (Vork Technologies) · Basado en arquitectura libre AGPL-3.0 · ${REPO_URL}`;
// Nombre del paquete en npm
export const PACKAGE_NAME = "vork-cli";
