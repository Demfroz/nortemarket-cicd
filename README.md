# NorteMarket S.A.C. — Flujo CI/CD automatizado

Proyecto demostrativo de la Tarea Académica 1 del curso *Herramientas de Desarrollo
Profesional TIC*. Implementa el flujo diseñado en el informe: **compilación, pruebas
automatizadas y despliegue** sobre **GitHub Actions + Docker**, con el despliegue
**simulado** en el propio runner (los contenedores representan las tareas de Amazon
ECS Fargate descritas en la arquitectura).

## Qué contiene

| Ruta | Qué es |
|---|---|
| `src/` | API de pedidos (Node.js + Express): catálogo, creación de pedidos y ruta `/health` |
| `tests/unit/` | Pruebas unitarias con Jest (lógica de totales, descuentos y envío) |
| `tests/integration/` | Pruebas de integración con Supertest sobre la API |
| `Dockerfile` | Imagen **multietapa**: compila en una etapa y ejecuta en otra, sin root |
| `.github/workflows/ci-cd.yml` | El pipeline: 6 etapas + compuerta de aprobación manual |
| `scripts/deploy-staging.sh` | Etapa 4 · despliegue automático en staging |
| `scripts/e2e-test.sh` | Pruebas E2E y de carga sobre staging |
| `scripts/deploy-bluegreen.sh` | Etapa 5 · blue/green con desvío 10 % → 50 % → 100 % |
| `scripts/rollback.sh` | Reversión automática al grupo azul |
| `scripts/smoke-test.sh` | Etapa 6 · verificación de rutas críticas en producción |
| `scripts/simular-pipeline.sh` | Ejecuta todo el pipeline en la PC (Git Bash / Linux) |
| `scripts/simular-pipeline.ps1` | Lo mismo, para Windows con PowerShell |

## Correspondencia con el informe

| Etapa del informe | Implementación aquí |
|---|---|
| Compilación con caché de dependencias | `actions/setup-node` con `cache: npm` + `npm run build` |
| Análisis estático en paralelo | Job `analisis-estatico` sin `needs` sobre la compilación |
| Pirámide de pruebas | Jest (unitarias, 80 % de cobertura), Supertest (integración), E2E y carga en staging |
| Imagen inmutable y trazable | Etiquetada con el SHA del commit, nunca `latest` |
| Escaneo de vulnerabilidades | Trivy sobre la imagen construida |
| Publicación en registro privado | Artefacto del pipeline (equivale al `docker push` a Amazon ECR) |
| Staging automático, producción con aprobación | Entornos `staging` y `production` de GitHub; el segundo con revisor obligatorio |
| Blue/green con reversión automática | `deploy-bluegreen.sh` + `rollback.sh` ante error superior al umbral |
| Registro de quién aprueba | Historial del entorno `production` y resumen del job |

## Uso rápido

```bash
npm install          # genera package-lock.json (obligatorio antes del primer push)
npm test             # pruebas unitarias e integración con cobertura
npm run lint         # análisis estático
# pipeline completo en local (requiere Docker Desktop encendido)
# Windows / PowerShell:
powershell -ExecutionPolicy Bypass -File scripts\simular-pipeline.ps1
# Git Bash o Linux:
bash scripts/simular-pipeline.sh
```

Los pasos detallados están en `docs/GUIA_PASO_A_PASO.md`.
