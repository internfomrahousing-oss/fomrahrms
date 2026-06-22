require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const authRoutes       = require('./routes/auth');
const employeeRoutes   = require('./routes/employees');
const leaveRoutes      = require('./routes/leaves');
const taskRoutes       = require('./routes/tasks');
const attendanceRoutes = require('./routes/attendance');

const app  = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

// Routes
app.use('/api/auth',       authRoutes);
app.use('/api/employees',  employeeRoutes);
app.use('/api/leaves',     leaveRoutes);
app.use('/api/tasks',      taskRoutes);
app.use('/api/attendance', attendanceRoutes);

// 404
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));

// Error handler
app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`FOMRA HRMS API running on http://0.0.0.0:${PORT}`);
});
