'use strict';

const express = require('express');
const { calcularTotal } = require('./pricing');

const VERSION = process.env.APP_VERSION || 'dev';
const ENTORNO = process.env.APP_ENV || 'local';
const COLOR = process.env.DEPLOY_COLOR || 'blue';

function crearApp() {
  const app = express();
  app.use(express.json());

  // Ruta que usa el balanceador y CloudWatch para saber si la tarea está sana.
  app.get('/health', (req, res) => {
    res.json({ estado: 'ok', version: VERSION, entorno: ENTORNO, color: COLOR });
  });

  app.get('/api/catalogo', (req, res) => {
    res.json([
      { sku: 'TV-55-4K', nombre: 'Televisor 55" 4K', precio: 1899.9, stock: 12 },
      { sku: 'REF-350L', nombre: 'Refrigeradora 350 L', precio: 2499.0, stock: 5 },
      { sku: 'MIC-20L', nombre: 'Microondas 20 L', precio: 349.9, stock: 40 }
    ]);
  });

  app.post('/api/pedidos', (req, res) => {
    const { items, cupon, departamento } = req.body || {};
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'El pedido debe incluir al menos un ítem' });
    }
    try {
      const montos = calcularTotal(items, { cupon, departamento });
      return res.status(201).json({
        id: `PED-${Date.now()}`,
        estado: 'registrado',
        version: VERSION,
        ...montos
      });
    } catch (error) {
      return res.status(422).json({ error: error.message });
    }
  });

  app.use((req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));

  return app;
}

module.exports = { crearApp, VERSION, ENTORNO, COLOR };
