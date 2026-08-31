'use strict';

const request = require('supertest');
const { crearApp } = require('../../src/app');

const app = crearApp();

describe('API de NorteMarket', () => {
  test('GET /health responde 200 y expone la versión', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.estado).toBe('ok');
    expect(res.body).toHaveProperty('version');
  });

  test('GET /api/catalogo devuelve productos con SKU y precio', async () => {
    const res = await request(app).get('/api/catalogo');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body[0]).toHaveProperty('sku');
    expect(res.body[0]).toHaveProperty('precio');
  });

  test('POST /api/pedidos crea el pedido y calcula el total', async () => {
    const res = await request(app)
      .post('/api/pedidos')
      .send({ items: [{ precio: 349.9, cantidad: 2 }], cupon: 'CYBER10' });
    expect(res.status).toBe(201);
    expect(res.body.estado).toBe('registrado');
    expect(res.body.total).toBeCloseTo(743.19, 2);
  });

  test('POST /api/pedidos rechaza un carrito vacío con 400', async () => {
    const res = await request(app).post('/api/pedidos').send({ items: [] });
    expect(res.status).toBe(400);
  });

  test('POST /api/pedidos devuelve 422 ante datos inválidos', async () => {
    const res = await request(app).post('/api/pedidos').send({ items: [{ precio: -5, cantidad: 1 }] });
    expect(res.status).toBe(422);
  });

  test('una ruta inexistente devuelve 404', async () => {
    const res = await request(app).get('/no-existe');
    expect(res.status).toBe(404);
  });
});
