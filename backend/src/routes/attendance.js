const router = require('express').Router();
const db     = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

// GET /api/attendance  — all records (HR)
router.get('/', authenticate, requireRole('hr', 'reportingManager'), async (req, res) => {
  try {
    const { date, employee } = req.query;
    let q = 'SELECT * FROM attendance_records WHERE 1=1';
    const params = [];

    if (date) {
      params.push(date);
      q += ` AND date = $${params.length}`;
    }
    if (employee) {
      params.push(`%${employee}%`);
      q += ` AND employee_name ILIKE $${params.length}`;
    }
    q += ' ORDER BY date DESC, created_at DESC';

    const result = await db.query(q, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/attendance/my  — current user records
router.get('/my', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM attendance_records
       WHERE employee_name ILIKE $1
       ORDER BY date DESC`,
      [req.user.name]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/attendance/check-in
router.post('/check-in', authenticate, async (req, res) => {
  try {
    const { check_in_time, location } = req.body;
    const today = new Date().toISOString().split('T')[0];

    // Upsert today's record
    const result = await db.query(
      `INSERT INTO attendance_records (employee_name, date, check_in_time, location, status)
       VALUES ($1, $2, $3, $4, 'present')
       ON CONFLICT DO NOTHING
       RETURNING *`,
      [req.user.name, today, check_in_time, location || '']
    );

    if (result.rows[0]) return res.status(201).json(result.rows[0]);

    // Row already exists — return existing
    const existing = await db.query(
      'SELECT * FROM attendance_records WHERE employee_name=$1 AND date=$2',
      [req.user.name, today]
    );
    res.json(existing.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/attendance/check-out
router.patch('/check-out', authenticate, async (req, res) => {
  try {
    const { check_out_time, location } = req.body;
    const today = new Date().toISOString().split('T')[0];

    const result = await db.query(
      `UPDATE attendance_records
       SET check_out_time=$1
       WHERE employee_name=$2 AND date=$3
       RETURNING *`,
      [check_out_time, req.user.name, today]
    );
    if (!result.rows[0])
      return res.status(404).json({ error: 'No check-in record for today' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
