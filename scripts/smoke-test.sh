#!/usr/bin/env bash
# ETAPA 6 — Smoke tests sobre las rutas críticas tras publicar en producción.
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-log.sh

BASE="http://localhost:${PUERTO_PROD:-3011}"
fallos=0
paso "Verificación posterior al despliegue (smoke tests)"

for ruta in "/health" "/api/catalogo"; do
  if curl -fsS "${BASE}${ruta}" >/dev/null; then ok "ruta crítica ${ruta} disponible"
  else fallo "ruta crítica ${ruta} caída"; fallos=$((fallos+1)); fi
done

if curl -fsS -X POST "${BASE}/api/pedidos" -H 'Content-Type: application/json' \
    -d '{"items":[{"precio":100,"cantidad":1}]}' >/dev/null; then
  ok "flujo de pago responde correctamente"
else fallo "flujo de pago no responde"; fallos=$((fallos+1)); fi

if [ "$fallos" -gt 0 ]; then
  fallo "smoke tests fallidos → se dispara la reversión"
  bash scripts/rollback.sh; exit 1
fi
paso "Servicio verificado en producción"
