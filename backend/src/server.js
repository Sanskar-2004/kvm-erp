require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');
const syncRoutes = require('./routes/syncRoutes');
const studentRoutes = require('./routes/studentRoutes');
const feeRoutes = require('./routes/feeRoutes');
const timetableRoutes = require('./routes/timetableRoutes');
const adminRoutes = require('./routes/adminRoutes');
const parentRoutes = require('./routes/parentRoutes');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Health Check
app.get('/', (req, res) => {
  res.send('KVM ERP Backend Running 🚀');
});

// Route Mounts
app.use('/api/auth', authRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/fees', feeRoutes);
app.use('/api/timetable', timetableRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/parent', parentRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`[Express] KVM ERP Master Backend actively auditing on port ${PORT}`);
});
