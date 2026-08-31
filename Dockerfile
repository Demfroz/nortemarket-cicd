# ---------- Etapa 1: compilación ----------
# Se instalan TODAS las dependencias (incluidas las de desarrollo) y se compila.
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---------- Etapa 2: ejecución ----------
# Solo dependencias de producción + el artefacto. La imagen final no lleva
# compiladores, pruebas ni código fuente de desarrollo: pesa menos y expone menos.
FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/dist ./dist

# No ejecutar como root: requisito de las pasarelas de pago.
RUN addgroup -S app && adduser -S app -G app
USER app

ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
ENV PORT=3000
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "dist/src/server.js"]
