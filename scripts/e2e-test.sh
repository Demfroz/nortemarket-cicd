#!/usr/bin/env bash
# ETAPA 4 — Pruebas E2E y de carga contra STAGING (equivalen a Cypress + k6).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib-log.sh

BASE="http://localhost:${PUERTO_STAGING:-3001}"
fallos=0

paso "Pruebas de extremo a extremo sobre staging"

probar() {   # probar <descripción> <esperado> <curl args...>
  local desc="$1" esperado="$2"; shift 2
  local codigo
  codigo=$(curl -s -o /tmp/e2e_body -w '%{http_code}' "$@")
  if [ "$codigo" = "$esperado" ]; then ok "$desc (HTTP $codigo)"
  else fallo "$desc — esperado $esperado, recibido $codigo"; fallos=$((fallos+1)); fi
}

probar "Recorrido 1: la tienda responde"        200 "$BASE/health"
probar "Recorrido 2: el catálogo carga"          200 "$BASE/api/catalogo"
probar "Recorrido 3: compra con cupón CYBER10"   201 -X POST "$BASE/api/pedidos" \
  -H 'Content-Type: application/json' -d '{"items":[{"precio":349.9,"cantidad":2}],"cupon":"CYBER10"}'
probar "Recorrido 4: carrito vacío se rechaza"   400 -X POST "$BASE/api/pedidos" \
  -H 'Content-Type: application/json' -d '{"items":[]}'
probar "Recorrido 5: datos inválidos → 422"      422 -X POST "$BASE/api/pedidos" \
  -H 'Content-Type: application/json' -d '{"items":[{"precio":-5,"cantidad":1}]}'

paso "Prueba de carga (equivalente reducido de k6)"
log "Enviando 200 peticiones para medir latencia"
inicio=$(date +%s%N)
for _ in $(seq 1 200); do curl -fsS "$BASE/api/catalogo" >/dev/null || fallos=$((fallos+1)); done
fin=$(date +%s%N)
prom=$(( (fin - inicio) / 200 / 1000000 ))
ok "latencia media: ${prom} ms por petición (criterio: p95 < 800 ms)"

if [ "$fallos" -gt 0 ]; then fallo "$fallos prueba(s) fallida(s): el pipeline se detiene"; exit 1; fi
paso "Todas las pruebas E2E pasaron · staging validado"
