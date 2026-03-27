'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// In-memory store (replace with a real DB in production)
let products = [
  { id: '1', name: 'Laptop Pro X', category: 'Electronics', quantity: 42, price: 1499.99 },
  { id: '2', name: 'Wireless Mouse', category: 'Accessories', quantity: 150, price: 29.99 },
  { id: '3', name: 'USB-C Hub', category: 'Accessories', quantity: 75, price: 49.99 },
  { id: '4', name: 'Monitor 27"', category: 'Electronics', quantity: 30, price: 399.99 },
];

// GET /api/products — list all products
router.get('/', (req, res) => {
  const { category, minQty } = req.query;
  let result = [...products];

  if (category) {
    result = result.filter(p => p.category.toLowerCase() === category.toLowerCase());
  }
  if (minQty) {
    result = result.filter(p => p.quantity >= parseInt(minQty, 10));
  }

  res.json({ count: result.length, products: result });
});

// GET /api/products/:id — get single product
router.get('/:id', (req, res) => {
  const product = products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ error: `Product with id '${req.params.id}' not found` });
  }
  res.json(product);
});

// POST /api/products — create product
router.post('/', (req, res) => {
  const { name, category, quantity, price } = req.body;

  if (!name || !category || quantity === undefined || price === undefined) {
    return res.status(400).json({
      error: 'Missing required fields: name, category, quantity, price',
    });
  }

  const product = {
    id: uuidv4(),
    name,
    category,
    quantity: parseInt(quantity, 10),
    price: parseFloat(price),
  };

  products.push(product);
  res.status(201).json(product);
});

// PUT /api/products/:id — update product
router.put('/:id', (req, res) => {
  const index = products.findIndex(p => p.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: `Product with id '${req.params.id}' not found` });
  }

  products[index] = { ...products[index], ...req.body, id: req.params.id };
  res.json(products[index]);
});

// DELETE /api/products/:id — delete product
router.delete('/:id', (req, res) => {
  const index = products.findIndex(p => p.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: `Product with id '${req.params.id}' not found` });
  }

  products.splice(index, 1);
  res.status(204).send();
});

// Expose products array for tests
router._products = products;
router._resetProducts = () => {
  products = [
    { id: '1', name: 'Laptop Pro X', category: 'Electronics', quantity: 42, price: 1499.99 },
    { id: '2', name: 'Wireless Mouse', category: 'Accessories', quantity: 150, price: 29.99 },
  ];
};

module.exports = router;
