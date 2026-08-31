'use strict';

const { crearApp, VERSION, ENTORNO, COLOR } = require('./app');

const PUERTO = process.env.PORT || 3000;

crearApp().listen(PUERTO, () => {
  // eslint-disable-next-line no-console
  console.log(`NorteMarket API ${VERSION} (${COLOR}) escuchando en :${PUERTO} [${ENTORNO}]`);
});
