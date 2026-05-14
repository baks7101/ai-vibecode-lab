require('dotenv').config();

const express = require('express');
const chatRouter = require('./routes/chat');
const { router: adminRouter } = require('./routes/admin');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.use('/api/chat', chatRouter);
app.use('/api/admin', adminRouter);

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Listening on http://localhost:${PORT}`);
});
