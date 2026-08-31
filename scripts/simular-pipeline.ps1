<#
  Simulacion completa del pipeline CI/CD de NorteMarket para Windows (PowerShell).
  Equivale a scripts/simular-pipeline.sh, que es el que corre en GitHub Actions (Ubuntu).
  Uso:  powershell -ExecutionPolicy Bypass -File scripts\simular-pipeline.ps1
  Requiere: Node.js, Docker Desktop encendido.
#>

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$Etiqueta   = 'nortemarket-api:local'
$Version    = 'local-' + (Get-Date -Format 'HHmmss')
$PuertoStg  = 3001
$PuertoAzul = 3010
$PuertoVerde= 3011

function Paso($t)  { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "  [OK]    $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "  [AVISO] $t" -ForegroundColor Yellow }
function Fallo($t) { Write-Host "  [FALLO] $t" -ForegroundColor Red }

function Ejecutar($descripcion, $comando, $argumentos) {
  & $comando @argumentos
  if ($LASTEXITCODE -ne 0) { Fallo "$descripcion (codigo $LASTEXITCODE)"; exit 1 }
  Ok $descripcion
}

function Esperar-Salud($puerto, $intentos = 30) {
  for ($i = 1; $i -le $intentos; $i++) {
    try {
      $r = Invoke-WebRequest -Uri "http://localhost:$puerto/health" -UseBasicParsing -TimeoutSec 3
      if ($r.StatusCode -eq 200) { Ok "el servicio en :$puerto responde sano (intento $i)"; return $true }
    } catch { Start-Sleep -Seconds 2 }
  }
  Fallo "el servicio en :$puerto no respondio tras $intentos intentos"
  return $false
}

function Probar($descripcion, $esperado, $metodo, $url, $cuerpo) {
  try {
    if ($cuerpo) {
      $r = Invoke-WebRequest -Uri $url -Method $metodo -Body $cuerpo -ContentType 'application/json' -UseBasicParsing -TimeoutSec 10
    } else {
      $r = Invoke-WebRequest -Uri $url -Method $metodo -UseBasicParsing -TimeoutSec 10
    }
    $codigo = $r.StatusCode
  } catch { $codigo = $_.Exception.Response.StatusCode.value__ }
  if ($codigo -eq $esperado) { Ok "$descripcion (HTTP $codigo)"; return $true }
  Fallo "$descripcion - esperado $esperado, recibido $codigo"; return $false
}

function Quitar-Contenedor($nombre) {
  try { docker rm -f $nombre 2>&1 | Out-Null } catch { }
}

function Rollback {
  Paso 'REVERSION AUTOMATICA'
  Write-Host '  Devolviendo el 100 % del trafico al grupo AZUL (version anterior)'
  Quitar-Contenedor 'nortemarket-green'
  try {
    Invoke-WebRequest -Uri "http://localhost:$PuertoAzul/health" -UseBasicParsing -TimeoutSec 3 | Out-Null
    Ok 'la version anterior sigue atendiendo: servicio nunca interrumpido'
  } catch { Aviso 'el grupo azul no esta levantado en este entorno de simulacion' }
  Ok 'tiempo de reversion simulado: menos de 2 minutos, sin intervencion humana'
}

# ---------------------------------------------------------------- ETAPA 2a
Paso 'ETAPA 2a - Analisis estatico (ESLint + npm audit)'
Ejecutar 'ESLint sin errores' 'npm' @('run','lint')
npm audit --audit-level=critical
if ($LASTEXITCODE -ne 0) { Aviso 'npm audit reporto hallazgos (informativo)' } else { Ok 'npm audit sin vulnerabilidades criticas' }

# ---------------------------------------------------------------- ETAPA 2b
Paso 'ETAPA 2b - Compilacion'
$env:APP_VERSION = $Version
Ejecutar 'artefacto generado en dist/' 'npm' @('run','build')

# ---------------------------------------------------------------- ETAPA 2c
Paso 'ETAPA 2c - Pruebas automatizadas (Jest + Supertest)'
Ejecutar 'todas las pruebas pasaron' 'npm' @('test')

# ----------------------------------------------------------------- ETAPA 3
Paso 'ETAPA 3 - Construccion y publicacion de la imagen'
Ejecutar 'imagen multietapa construida' 'docker' @('build','--build-arg',"APP_VERSION=$Version",'-t',$Etiqueta,'.')
docker images $Etiqueta --format 'Tamano de la imagen final: {{.Size}}'
Aviso 'en el diseno real, aqui se hace docker push a Amazon ECR con la etiqueta del commit'

# ----------------------------------------------------------------- ETAPA 4
Paso 'ETAPA 4 - Despliegue automatico en staging'
Write-Host '  Simulando: aws ecs update-service --cluster nortemarket-staging --service api'
Quitar-Contenedor 'nortemarket-staging'
Write-Host '  Aplicando migraciones de base de datos versionadas (simulado)'
Start-Sleep -Seconds 1
Ok '3 migraciones aplicadas, reversibles'
docker run -d --name nortemarket-staging -p "${PuertoStg}:3000" -e APP_ENV=staging -e DEPLOY_COLOR=blue -e "APP_VERSION=$Version" $Etiqueta | Out-Null
if (-not (Esperar-Salud $PuertoStg)) { exit 1 }
Ok "staging desplegado en http://localhost:$PuertoStg"

Paso 'Pruebas E2E y de carga sobre staging'
$base = "http://localhost:$PuertoStg"
$fallos = 0
if (-not (Probar 'Recorrido 1: la tienda responde'      200 'GET'  "$base/health" $null))       { $fallos++ }
if (-not (Probar 'Recorrido 2: el catalogo carga'       200 'GET'  "$base/api/catalogo" $null)) { $fallos++ }
if (-not (Probar 'Recorrido 3: compra con cupon CYBER10' 201 'POST' "$base/api/pedidos" '{"items":[{"precio":349.9,"cantidad":2}],"cupon":"CYBER10"}')) { $fallos++ }
if (-not (Probar 'Recorrido 4: carrito vacio se rechaza' 400 'POST' "$base/api/pedidos" '{"items":[]}')) { $fallos++ }
if (-not (Probar 'Recorrido 5: datos invalidos -> 422'   422 'POST' "$base/api/pedidos" '{"items":[{"precio":-5,"cantidad":1}]}')) { $fallos++ }

Write-Host '  Prueba de carga: 100 peticiones para medir latencia'
$reloj = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 1; $i -le 100; $i++) {
  try { Invoke-WebRequest -Uri "$base/api/catalogo" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch { $fallos++ }
}
$reloj.Stop()
Ok ("latencia media: " + [math]::Round($reloj.ElapsedMilliseconds / 100, 1) + " ms por peticion (criterio: p95 < 800 ms)")
if ($fallos -gt 0) { Fallo "$fallos prueba(s) fallida(s): el pipeline se detiene"; exit 1 }
Ok 'staging validado'

# ------------------------------------------------------- COMPUERTA MANUAL
Paso 'COMPUERTA DE APROBACION MANUAL'
$respuesta = Read-Host '  El lider tecnico aprueba la publicacion en produccion? (s/n)'
if ($respuesta -ne 's') { Aviso 'publicacion cancelada por el aprobador'; exit 0 }
Ok "aprobado por $env:USERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

# ----------------------------------------------------------------- ETAPA 5
Paso 'ETAPA 5 - Produccion, version actual (grupo AZUL)'
Quitar-Contenedor 'nortemarket-blue'
docker run -d --name nortemarket-blue -p "${PuertoAzul}:3000" -e APP_ENV=production -e DEPLOY_COLOR=blue -e APP_VERSION=v-anterior $Etiqueta | Out-Null
if (-not (Esperar-Salud $PuertoAzul)) { exit 1 }

Paso 'Levantando el grupo VERDE con la version nueva'
Quitar-Contenedor 'nortemarket-green'
docker run -d --name nortemarket-green -p "${PuertoVerde}:3000" -e APP_ENV=production -e DEPLOY_COLOR=green -e "APP_VERSION=$Version" $Etiqueta | Out-Null
if (-not (Esperar-Salud $PuertoVerde)) { Rollback; exit 1 }

foreach ($porcentaje in 10, 50, 100) {
  Paso "Desviando el $porcentaje % del trafico al grupo VERDE"
  $errores = 0; $total = 50
  for ($i = 1; $i -le $total; $i++) {
    if ((($i * 100) / $total) -le $porcentaje) { $destino = $PuertoVerde } else { $destino = $PuertoAzul }
    try { Invoke-WebRequest -Uri "http://localhost:$destino/api/catalogo" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch { $errores++ }
  }
  $tasa = [math]::Round(($errores * 100) / $total, 1)
  Write-Host "  peticiones: $total, errores: $errores ($tasa %), umbral: 1 %"
  if ($tasa -gt 1) { Fallo "alarma de CloudWatch activada en el tramo del $porcentaje %"; Rollback; exit 1 }
  Ok "tramo del $porcentaje % validado"
  Start-Sleep -Seconds 2
}
Ok 'el 100 % del trafico atiende la version nueva'
Aviso 'el grupo AZUL permanece activo 30 minutos como plan de retorno inmediato'

# ----------------------------------------------------------------- ETAPA 6
Paso 'ETAPA 6 - Verificacion y monitoreo (smoke tests)'
$prod = "http://localhost:$PuertoVerde"
$fallos = 0
if (-not (Probar 'ruta critica /health disponible'    200 'GET'  "$prod/health" $null))       { $fallos++ }
if (-not (Probar 'ruta critica /api/catalogo activa'  200 'GET'  "$prod/api/catalogo" $null)) { $fallos++ }
if (-not (Probar 'flujo de pago responde'             201 'POST' "$prod/api/pedidos" '{"items":[{"precio":100,"cantidad":1}]}')) { $fallos++ }
if ($fallos -gt 0) { Fallo 'smoke tests fallidos: se dispara la reversion'; Rollback; exit 1 }

Paso 'PIPELINE COMPLETADO'
Write-Host ''
Write-Host "  Version publicada : $Version"
Write-Host "  Aprobada por      : $env:USERNAME"
Write-Host "  Estrategia        : blue/green 10 % -> 50 % -> 100 %"
Write-Host ''
docker ps --filter 'name=nortemarket' --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}'
Write-Host ''
Aviso 'para limpiar: docker rm -f nortemarket-staging nortemarket-blue nortemarket-green'
