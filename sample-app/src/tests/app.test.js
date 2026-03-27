'use strict';

const request = require('supertest');
const app = require('../app');

describe('Health & Root Endpoints', () => {
  test('GET / returns service info', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.service).toBe('InventoryAPI');
  });

  test('GET /health returns healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('timestamp');
  });

  test('GET /ready returns ready status', async () => {
    const res = await request(app).get('/ready');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ready');
  });

  test('GET /nonexistent returns 404', async () => {
    const res = await request(app).get('/nonexistent');
    expect(res.statusCode).toBe(404);
  });
});

describe('Products API', () => {
  test('GET /api/products returns product list', async () => {
    const res = await request(app).get('/api/products');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('products');
    expect(Array.isArray(res.body.products)).toBe(true);
    expect(res.body.count).toBeGreaterThan(0);
  });

  test('GET /api/products/:id returns single product', async () => {
    const res = await request(app).get('/api/products/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe('1');
    expect(res.body.name).toBe('Laptop Pro X');
  });

  test('GET /api/products/:id returns 404 for missing product', async () => {
    const res = await request(app).get('/api/products/9999');
    expect(res.statusCode).toBe(404);
    expect(res.body).toHaveProperty('error');
  });

  test('POST /api/products creates a new product', async () => {
    const newProduct = {
      name: 'Keyboard Mechanical',
      category: 'Accessories',
      quantity: 50,
      price: 89.99,
    };
    const res = await request(app)
      .post('/api/products')
      .send(newProduct);
    expect(res.statusCode).toBe(201);
    expect(res.body.name).toBe('Keyboard Mechanical');
    expect(res.body).toHaveProperty('id');
  });

  test('POST /api/products returns 400 for missing fields', async () => {
    const res = await request(app)
      .post('/api/products')
      .send({ name: 'Incomplete Product' });
    expect(res.statusCode).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  test('GET /api/products with category filter', async () => {
    const res = await request(app).get('/api/products?category=Electronics');
    expect(res.statusCode).toBe(200);
    res.body.products.forEach(p => {
      expect(p.category).toBe('Electronics');
    });
  });

  test('PUT /api/products/:id updates a product', async () => {
    const res = await request(app)
      .put('/api/products/1')
      .send({ quantity: 100 });
    expect(res.statusCode).toBe(200);
    expect(res.body.quantity).toBe(100);
  });

  test('DELETE /api/products/:id deletes a product', async () => {
    // First create one to delete
    const createRes = await request(app)
      .post('/api/products')
      .send({ name: 'To Delete', category: 'Test', quantity: 1, price: 1.0 });
    const id = createRes.body.id;

    const deleteRes = await request(app).delete(`/api/products/${id}`);
    expect(deleteRes.statusCode).toBe(204);

    const getRes = await request(app).get(`/api/products/${id}`);
    expect(getRes.statusCode).toBe(404);
  });
});
