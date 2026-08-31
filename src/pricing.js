'use strict';

const IGV = 0.18;

/** Cupones vigentes de la campaña. */
const CUPONES = {
  CYBER10: 0.10,
  CYBER25: 0.25,
  BIENVENIDO: 0.05
};

/**
 * Calcula el subtotal de un carrito.
 * @param {Array<{precio:number, cantidad:number}>} items
 */
function calcularSubtotal(items) {
  if (!Array.isArray(items)) {
    throw new TypeError('items debe ser un arreglo');
  }
  return items.reduce((acc, item) => {
    if (typeof item.precio !== 'number' || item.precio < 0) {
      throw new RangeError('precio inválido');
    }
    if (!Number.isInteger(item.cantidad) || item.cantidad <= 0) {
      throw new RangeError('cantidad inválida');
    }
    return acc + item.precio * item.cantidad;
  }, 0);
}

/** Aplica un cupón sobre un monto. Un cupón inexistente no descuenta nada. */
function aplicarDescuento(monto, cupon) {
  const tasa = CUPONES[cupon] || 0;
  return redondear(monto * (1 - tasa));
}

/** El envío es gratuito a partir de S/ 150. */
function calcularEnvio(subtotal, departamento = 'Lambayeque') {
  if (subtotal >= 150) return 0;
  return departamento === 'Lambayeque' ? 10 : 18;
}

function redondear(valor) {
  return Math.round(valor * 100) / 100;
}

/**
 * Calcula el total del pedido: subtotal, descuento, IGV y envío.
 */
function calcularTotal(items, { cupon = null, departamento = 'Lambayeque' } = {}) {
  const subtotal = redondear(calcularSubtotal(items));
  const conDescuento = aplicarDescuento(subtotal, cupon);
  const igv = redondear(conDescuento * IGV);
  const envio = calcularEnvio(conDescuento, departamento);
  return {
    subtotal,
    descuento: redondear(subtotal - conDescuento),
    igv,
    envio,
    total: redondear(conDescuento + igv + envio)
  };
}

module.exports = { calcularSubtotal, aplicarDescuento, calcularEnvio, calcularTotal, IGV, CUPONES };
