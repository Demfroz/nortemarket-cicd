'use strict';

const { calcularSubtotal, aplicarDescuento, calcularEnvio, calcularTotal } = require('../../src/pricing');

describe('calcularSubtotal', () => {
  test('suma precio por cantidad de cada ítem', () => {
    expect(calcularSubtotal([{ precio: 100, cantidad: 2 }, { precio: 50, cantidad: 1 }])).toBe(250);
  });

  test('un carrito vacío vale cero', () => {
    expect(calcularSubtotal([])).toBe(0);
  });

  test('rechaza cantidades no enteras o negativas', () => {
    expect(() => calcularSubtotal([{ precio: 100, cantidad: 0 }])).toThrow(RangeError);
    expect(() => calcularSubtotal([{ precio: 100, cantidad: 1.5 }])).toThrow(RangeError);
  });

  test('rechaza precios negativos', () => {
    expect(() => calcularSubtotal([{ precio: -1, cantidad: 1 }])).toThrow(RangeError);
  });

  test('rechaza un argumento que no sea arreglo', () => {
    expect(() => calcularSubtotal('carrito')).toThrow(TypeError);
  });
});

describe('aplicarDescuento', () => {
  test('CYBER25 descuenta el 25 %', () => {
    expect(aplicarDescuento(1000, 'CYBER25')).toBe(750);
  });

  test('CYBER40 descuenta el 40 %', () => {
  expect(aplicarDescuento(1000, 'CYBER40')).toBe(600);
});

  test('un cupón inexistente no altera el monto', () => {
    expect(aplicarDescuento(1000, 'NOEXISTE')).toBe(1000);
  });
});

describe('calcularEnvio', () => {
  test('es gratuito desde S/ 150', () => {
    expect(calcularEnvio(150)).toBe(0);
  });

  test('cuesta S/ 10 dentro de Lambayeque', () => {
    expect(calcularEnvio(100, 'Lambayeque')).toBe(10);
  });

  test('cuesta S/ 18 fuera de Lambayeque', () => {
    expect(calcularEnvio(100, 'Piura')).toBe(18);
  });
});

describe('calcularTotal', () => {
  test('integra descuento, IGV y envío', () => {
    const r = calcularTotal([{ precio: 100, cantidad: 1 }], { cupon: 'CYBER10', departamento: 'Piura' });
    expect(r).toEqual({ subtotal: 100, descuento: 10, igv: 16.2, envio: 18, total: 124.2 });
  });

  test('supera el umbral de envío gratuito en una compra grande', () => {
    const r = calcularTotal([{ precio: 1899.9, cantidad: 1 }]);
    expect(r.envio).toBe(0);
    expect(r.total).toBe(2241.88);
  });
});
