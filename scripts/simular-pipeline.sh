#!/usr/bin/env bash
# Ejecuta el pipeline completo en la PC, en el mismo orden que GitHub Actions.
# Útil para ensayar la demostración antes de la exposición.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-log.sh

ETIQUETA="nortemarket-api:local"
export APP_VERSION="local-$(date +%H%M%S)"

paso "ETAPA 2a · Análisis estático (ESLint + npm audit)"
npm run lint
npm audit --audit-level=critical || aviso "npm audit reportó hallazgos (informativo)"

paso "ETAPA 2b · Compilación"
npm run build

paso "ETAPA 2c · Pruebas automatizadas"
npm test

paso "ETAPA 3 · Construcción y escaneo de la imagen"
docker build --build-arg APP_VERSION="$APP_VERSION" -t "$ETIQUETA" .
docker images "$ETIQUETA" --format 'Tamaño de la imagen final: {{.Size}}'

paso "ETAPA 4 · Despliegue automático en staging + pruebas E2E"
bash scripts/deploy-staging.sh "$ETIQUETA"
bash scripts/e2e-test.sh

paso "COMPUERTA DE APROBACIÓN MANUAL"
read -r -p "  ¿El líder técnico aprueba la publicación en producción? (s/n) " respuesta
if [ "$respuesta" != "s" ]; then aviso "publicación cancelada por el aprobador"; exit 0; fi

paso "ETAPA 5 · Producción blue/green"
bash scripts/deploy-bluegreen.sh "$ETIQUETA"

paso "ETAPA 6 · Verificación y monitoreo"
bash scripts/smoke-test.sh

paso "PIPELINE COMPLETADO"
docker ps --filter 'name=nortemarket' --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}'
aviso "para limpiar: docker rm -f nortemarket-staging nortemarket-blue nortemarket-green"
