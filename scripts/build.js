/**
 * Etapa de COMPILACIÓN.
 * En una aplicación real aquí se ejecutaría el empaquetador del frontend
 * (Vite/Webpack) y la transpilación del backend. Para el proyecto demostrativo
 * se genera el artefacto en dist/ con los metadatos de trazabilidad.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const RAIZ = path.join(__dirname, '..');
const DIST = path.join(RAIZ, 'dist');

fs.rmSync(DIST, { recursive: true, force: true });
fs.mkdirSync(DIST, { recursive: true });
fs.cpSync(path.join(RAIZ, 'src'), path.join(DIST, 'src'), { recursive: true });
fs.copyFileSync(path.join(RAIZ, 'package.json'), path.join(DIST, 'package.json'));

const info = {
  aplicacion: 'nortemarket-api',
  version: process.env.APP_VERSION || 'dev',
  commit: process.env.GITHUB_SHA || 'local',
  rama: process.env.GITHUB_REF_NAME || 'local',
  compiladoEn: new Date().toISOString()
};

fs.writeFileSync(path.join(DIST, 'build-info.json'), JSON.stringify(info, null, 2));
console.log('Compilación completada →', info.version, info.commit.slice(0, 7));
