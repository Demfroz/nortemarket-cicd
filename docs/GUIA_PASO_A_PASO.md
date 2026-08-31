# Guía paso a paso — Montar y demostrar el pipeline

Objetivo: tener el flujo CI/CD funcionando en GitHub Actions, con compilación,
pruebas automatizadas y **despliegue simulado**, tal como se describe en el informe.
Tiempo estimado: 45–60 minutos la primera vez.

---

## 0. Requisitos

En tu PC: **Node.js 20 o superior**, **Docker Desktop** (encendido) y **Git**.
Verifícalo en una terminal:

```bash
node -v && npm -v && git --version && docker --version
```

---

## 1. Preparar el proyecto en tu PC

La carpeta `nortemarket-cicd` ya está en tu Escritorio, dentro de `TIC`.
Abre una terminal ahí (clic derecho → *Git Bash Here*, o en PowerShell):

```bash
cd "$HOME/Desktop/TIC/nortemarket-cicd"
npm install
```

> **Paso obligatorio.** `npm install` genera `package-lock.json`, y el pipeline usa
> `npm ci`, que exige ese archivo. Sin él, el workflow falla en el primer job.

Comprueba que todo pasa en local antes de subir nada:

```bash
npm run lint     # análisis estático: sin errores
npm test         # 20 pruebas: unitarias + integración, con cobertura
npm run build    # genera dist/ con build-info.json
```

Si `npm test` termina en verde, ya tienes las etapas 1 y 2 del flujo funcionando.

---

## 1-bis. Colocar el archivo del workflow (importante)

Por seguridad, la carpeta `.github\workflows` no se pudo escribir automáticamente en tu
PC, así que ese archivo hay que ponerlo a mano una sola vez:

1. En este chat, descarga el archivo **`ci-cd.yml`**.
2. Dentro de `nortemarket-cicd`, crea la carpeta `.github` y dentro de ella `workflows`.
3. Mueve `ci-cd.yml` ahí. La ruta final debe ser exactamente:
   `nortemarket-cicd\.github\workflows\ci-cd.yml`

En Git Bash es más rápido:

```bash
mkdir -p .github/workflows
mv ~/Downloads/ci-cd.yml .github/workflows/ci-cd.yml
ls .github/workflows/     # debe listar ci-cd.yml
```

Sin ese archivo en esa ruta exacta, GitHub no ejecuta nada en la pestaña Actions.

---

## 2. Ensayar el pipeline completo en local (recomendado)

Con Docker Desktop encendido. **En PowerShell usa la version .ps1**, no `bash`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\simular-pipeline.ps1
```

> **Si escribiste `bash scripts/simular-pipeline.sh` en PowerShell** y saliste con
> `WSL (...) ERROR: execvpe(/bin/bash) failed`, no es un problema del proyecto: en
> Windows la palabra `bash` la atiende WSL, y no tienes una distribucion de Linux
> instalada. Tienes dos salidas:
>
> - **La recomendada:** usar el script de PowerShell de arriba. Hace exactamente lo mismo.
> - **La alternativa:** abrir **Git Bash** (clic derecho en la carpeta → *Open Git Bash here*)
>   y ahi si ejecutar `bash scripts/simular-pipeline.sh`.
>
> Los archivos `.sh` siguen siendo necesarios: son los que ejecuta GitHub Actions,
> que corre sobre Ubuntu. El `.ps1` existe solo para poder ensayar en tu PC.

Recorre las seis etapas en el mismo orden que GitHub Actions: análisis estático,
compilación, pruebas, construcción de la imagen, staging con pruebas E2E, la
**compuerta de aprobación** (te pregunta en la consola) y el despliegue blue/green
con verificación. Al final quedan tres contenedores corriendo: staging (`:3001`),
azul (`:3010`) y verde (`:3011`). Ábrelos en el navegador:

- http://localhost:3001/health → `"entorno":"staging"`
- http://localhost:3011/health → `"color":"green"`

Para limpiar: `docker rm -f nortemarket-staging nortemarket-blue nortemarket-green`

---

## 3. Subir el proyecto a GitHub

Crea un repositorio **público** llamado `nortemarket-cicd` (sin README ni .gitignore;
el proyecto ya los trae). Público importa: en repositorios privados los entornos con
aprobación obligatoria requieren un plan de pago, y esa compuerta es parte del diseño.

```bash
git init -b main
git add .
git commit -m "feat: pipeline CI/CD de NorteMarket con despliegue simulado"
git remote add origin https://github.com/TU-USUARIO/nortemarket-cicd.git
git push -u origin main
```

Entra a la pestaña **Actions**: el workflow ya se está ejecutando.

---

## 4. Configurar los entornos y la compuerta de aprobación

En el repositorio → **Settings** → **Environments**:

1. **New environment** → nombre `staging` → *Configure environment* → guardar sin reglas.
   Es el entorno de despliegue automático.
2. **New environment** → nombre `production` → marca **Required reviewers** y añade tu
   propio usuario (o el de un compañero, que queda mejor en la demostración) → **Save**.
3. Opcional: en *Deployment branches* elige **Selected branches** y agrega `main`.

Con esto, cualquier despliegue a producción queda detenido hasta que alguien apruebe,
y GitHub registra **quién aprobó, cuándo y sobre qué versión**: exactamente el
requisito de auditoría del informe.

---

## 5. Crear la estrategia de ramas

```bash
git checkout -b develop
git push -u origin develop
git checkout -b feature/cupon-cyber
```

Haz un cambio pequeño y visible, por ejemplo agregar un cupón en `src/pricing.js`:

```js
const CUPONES = {
  CYBER10: 0.10,
  CYBER25: 0.25,
  CYBER40: 0.40,      // ← nuevo cupón de campaña
  BIENVENIDO: 0.05
};
```

Agrega su prueba en `tests/unit/pricing.test.js`, dentro del bloque `aplicarDescuento`:

```js
test('CYBER40 descuenta el 40 %', () => {
  expect(aplicarDescuento(1000, 'CYBER40')).toBe(600);
});
```

```bash
git add . && git commit -m "feat: cupón CYBER40 para la campaña" && git push -u origin feature/cupon-cyber
```

---

## 6. La demostración completa (esto es lo que se enseña en clase)

**a) Pull Request → `develop`.** En GitHub, *Compare & pull request*.
Verás correr análisis estático, compilación y pruebas. El despliegue **no** se ejecuta:
los PR se quedan en la etapa 2, tal como está declarado en el `if` del workflow.

**b) Merge a `develop`.** Ahora sí corre la etapa 4: se construye la imagen etiquetada
con el SHA del commit, se despliega en staging y se ejecutan las pruebas E2E y de carga.

**c) Pull Request de `develop` a `main` y merge.** El pipeline llega al job
`5 y 6 · Producción` y **se detiene**: aparece el aviso *Review pending deployments*.
Esa pantalla es la compuerta de aprobación: muéstrala en la exposición.

**d) Aprobar.** Botón **Review deployments** → marca `production` → **Approve and deploy**.
Se ejecuta el blue/green: verás en el log el desvío del tráfico 10 % → 50 % → 100 % con
la tasa de error validada en cada tramo, después los smoke tests y, al final del job,
la tabla de resumen con la versión, la rama y quién aprobó.

---

## 7. Demostrar la reversión automática (opcional, pero impresiona)

Rompe a propósito una ruta crítica en una rama nueva, en `src/app.js`:

```js
app.get('/api/catalogo', (req, res) => {
  return res.status(500).json({ error: 'fallo simulado' });   // ← defecto introducido
});
```

Comenta temporalmente la prueba de integración del catálogo para que el defecto llegue
al despliegue (así se ve que el fallo se detecta en producción, no antes). Al aprobar,
`deploy-bluegreen.sh` detecta que la tasa de error supera el umbral del 1 % y ejecuta
`rollback.sh`: el tráfico vuelve al grupo azul y el job termina en rojo, con el servicio
nunca interrumpido. **Revierte ese cambio después** (`git revert` o deshaciendo la edición).

---

## 8. Evidencias para el informe

Captura estas pantallas y anéxalas:

1. Pestaña **Actions** con el workflow en verde y los seis jobs encadenados (el grafo).
2. Log del job de pruebas con la tabla de cobertura de Jest.
3. Log del job de imagen con el **tamaño de la imagen** y el reporte de Trivy.
4. Log de staging mostrando las pruebas E2E y la latencia media.
5. Pantalla **Review pending deployments** (la compuerta de aprobación).
6. Log del blue/green con los tramos 10 %, 50 % y 100 % validados.
7. Tabla de resumen del despliegue (aparece al final de la página del run).
8. **Settings → Environments → production** mostrando el revisor obligatorio.
9. Historial del entorno `production` con el registro de la aprobación.

---

## 9. Verificación de lo pedido por el docente

| Requisito | Dónde se demuestra |
|---|---|
| Compilación | Job `2b · Compilación`, con caché de dependencias y artefacto en `dist/` |
| Pruebas automatizadas | Job `2c` (Jest + Supertest, cobertura) y `scripts/e2e-test.sh` en staging |
| Despliegue simulado | Jobs `4 · Staging` y `5 y 6 · Producción`: contenedores Docker que representan las tareas de ECS Fargate |
| Herramienta usada | GitHub Actions (`.github/workflows/ci-cd.yml`) |
| Correspondencia con el diseño del informe | Las seis etapas, la compuerta manual, blue/green y la reversión automática |

---

## 10. Si algo falla

| Síntoma | Causa y solución |
|---|---|
| `npm ci can only install with an existing package-lock.json` | Faltó el paso 1: ejecuta `npm install` y sube el `package-lock.json` |
| `Dependencies lock file is not found` en setup-node | Lo mismo: el lockfile no está en el repositorio |
| El job de producción nunca pide aprobación | El entorno `production` no tiene *Required reviewers*, o el repositorio es privado sin plan de pago |
| El despliegue no se ejecuta | Es un Pull Request: por diseño solo corre en `develop` y `main` |
| `npm run lint` falla por `no-console` | Usa el comentario `// eslint-disable-next-line no-console` como en `src/server.js` |
| Docker falla en local | Docker Desktop no está encendido |
| Los puertos 3001/3010/3011 están ocupados | `docker rm -f nortemarket-staging nortemarket-blue nortemarket-green` |
