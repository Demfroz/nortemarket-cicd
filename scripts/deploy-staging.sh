#!/usr/bin/env bash
# ETAPA 4 — Despliegue automático en STAGING (simulado).
# En la arquitectura propuesta esto sería:
#   aws ecs update-service --cluster nortemarket-staging --service api --force-new-deployment
# Aquí se levanta la misma imagen Docker en un contenedor local que hace de "tarea de ECS Fargate".
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-log.sh

IMAGEN="${1:-nortemarket-api:local}"
PUERTO="${PUERTO_STAGING:-3001}"
CONTENEDOR="nortemarket-staging"

paso "Despliegue en staging · imagen ${IMAGEN}"

log "Simulando: aws ecs update-service --cluster nortemarket-staging --service api"
docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true

log "Aplicando migraciones de base de datos versionadas (simulado)"
sleep 1
ok "3 migraciones aplicadas · reversibles con 'migrate down'"

log "Levantando la nueva tarea"
docker run -d --name "$CONTENEDOR" -p "${PUERTO}:3000" \
  -e APP_ENV=staging -e DEPLOY_COLOR=blue \
  -e APP_VERSION="${APP_VERSION:-dev}" "$IMAGEN" >/dev/null

esperar_salud "$PUERTO"
curl -fsS "http://localhost:${PUERTO}/health"; echo
ok "staging actualizado en http://localhost:${PUERTO}"
