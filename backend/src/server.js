require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');
const syncRoutes = require('./routes/syncRoutes');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' })); // Allow massive SQLite pushes natively

// Render Health Check Route
app.get('/', (req, res) => {
  res.send('KVM ERP Backend Running 🚀');
});

app.use('/api/auth', authRoutes);
app.use('/api/sync', syncRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`[Express] KVM ERP Master Backend actively auditing on port ${PORT}`);
});
