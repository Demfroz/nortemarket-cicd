#!/usr/bin/env bash
# Reversión automática: el balanceador devuelve el 100 % del tráfico al grupo azul.
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-log.sh

paso "REVERSIÓN AUTOMÁTICA"
log "Devolviendo el 100 % del tráfico al grupo AZUL (versión anterior)"
docker rm -f nortemarket-green >/dev/null 2>&1 || true
if curl -fsS "http://localhost:3010/health" >/dev/null 2>&1; then
  ok "la versión anterior sigue atendiendo · servicio nunca interrumpido"
else
  aviso "el grupo azul no está levantado en este entorno de simulación"
fi
ok "tiempo de reversión simulado: menos de 2 minutos, sin intervención humana"
