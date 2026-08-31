#!/usr/bin/env bash
# Funciones de registro compartidas por los scripts de despliegue.
log()      { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
paso()     { printf '\n=== %s ===\n' "$*"; }
ok()       { printf '  [OK]    %s\n' "$*"; }
aviso()    { printf '  [AVISO] %s\n' "$*"; }
fallo()    { printf '  [FALLO] %s\n' "$*"; }

# Espera a que /health responda. Uso: esperar_salud <puerto> [intentos]
esperar_salud() {
  local puerto="$1" intentos="${2:-30}" i=1
  while [ "$i" -le "$intentos" ]; do
    if curl -fsS "http://localhost:${puerto}/health" >/dev/null 2>&1; then
      ok "el servicio en :${puerto} responde sano (intento ${i})"
      return 0
    fi
    sleep 2; i=$((i+1))
  done
  fallo "el servicio en :${puerto} no respondió tras ${intentos} intentos"
  return 1
}
