'use strict';

const express = require('express');
const client = require('prom-client');

const productsRouter = require('./routes/products');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'local';

// Prometheus metrics setup
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// Middleware
app.use(express.json());
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestCounter.inc({
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status_code: res.statusCode,
    });
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    version: APP_VERSION,
    environment: ENVIRONMENT,
    timestamp: new Date().toISOString(),
  });
});

// Readiness probe endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready' });
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// API routes
app.use('/api/products', productsRouter);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'InventoryAPI',
    version: APP_VERSION,
    environment: ENVIRONMENT,
    endpoints: [
      'GET  /health',
      'GET  /ready',
      'GET  /metrics',
      'GET  /api/products',
      'GET  /api/products/:id',
      'POST /api/products',
      'PUT  /api/products/:id',
      'DELETE /api/products/:id',
    ],
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server only when not in test mode
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`InventoryAPI v${APP_VERSION} running on port ${PORT} [${ENVIRONMENT}]`);
  });
}

module.exports = app;
