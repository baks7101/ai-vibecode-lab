const express = require('express');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
app.use(express.json());

const { register } = require('./metrics');

const chatRoutes = require('./routes/chat');
const adminRoutes = require('./routes/admin');

app.use('/api/chat', chatRoutes.router);
app.use('/api/admin', adminRoutes);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Error handler
app.use((err, req, res, next) => {
  res.status(500).json({
    error: err.message,
    stack: err.stack
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`MediTriage API running on port ${PORT}`);
});

module.exports = app;