#!/usr/bin/env bash
# ETAPA 5 — Despliegue en PRODUCCIÓN con estrategia blue/green (simulado).
# Equivale a AWS CodeDeploy desviando el tráfico del Application Load Balancer
# entre dos grupos de tareas de ECS Fargate: 10 % → 50 % → 100 %.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-log.sh

IMAGEN="${1:-nortemarket-api:local}"
AZUL=3010     # versión actual, sigue atendiendo
VERDE=3011    # versión nueva
UMBRAL_ERROR=1   # % máximo de errores tolerado en cada tramo

paso "Producción · versión actual (grupo AZUL)"
docker rm -f nortemarket-blue >/dev/null 2>&1 || true
docker run -d --name nortemarket-blue -p "${AZUL}:3000" \
  -e APP_ENV=production -e DEPLOY_COLOR=blue -e APP_VERSION=v-anterior "$IMAGEN" >/dev/null
esperar_salud "$AZUL"

paso "Levantando el grupo VERDE con la versión nueva"
docker rm -f nortemarket-green >/dev/null 2>&1 || true
docker run -d --name nortemarket-green -p "${VERDE}:3000" \
  -e APP_ENV=production -e DEPLOY_COLOR=green -e APP_VERSION="${APP_VERSION:-nueva}" "$IMAGEN" >/dev/null
if ! esperar_salud "$VERDE"; then
  fallo "el grupo verde nunca estuvo sano · el tráfico permanece 100 % en azul"
  bash scripts/rollback.sh; exit 1
fi

# Desvío progresivo del tráfico con validación de métricas en cada tramo.
for porcentaje in 10 50 100; do
  paso "Desviando el ${porcentaje} % del tráfico al grupo VERDE"
  errores=0; total=50
  for i in $(seq 1 $total); do
    if [ $(( (i * 100 / total) )) -le "$porcentaje" ]; then destino=$VERDE; else destino=$AZUL; fi
    curl -fsS "http://localhost:${destino}/api/catalogo" >/dev/null 2>&1 || errores=$((errores+1))
  done
  tasa=$(( errores * 100 / total ))
  log "peticiones: ${total} · errores: ${errores} (${tasa} %) · umbral: ${UMBRAL_ERROR} %"
  if [ "$tasa" -gt "$UMBRAL_ERROR" ]; then
    fallo "alarma de CloudWatch activada en el tramo del ${porcentaje} %"
    bash scripts/rollback.sh; exit 1
  fi
  ok "tramo del ${porcentaje} % validado"
  sleep 2
done

paso "Publicación completada"
curl -fsS "http://localhost:${VERDE}/health"; echo
ok "el 100 % del tráfico atiende la versión nueva"
aviso "el grupo AZUL permanece activo 30 minutos como plan de retorno inmediato"
