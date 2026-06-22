const router = require('express').Router();
const db     = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

// GET /api/leaves  — all applications (HR / Manager)
router.get('/', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM leave_applications ORDER BY applied_on DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/leaves/my  — current user's applications
router.get('/my', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM leave_applications
       WHERE employee_name ILIKE $1
       ORDER BY applied_on DESC`,
      [req.user.name]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/leaves  — submit new leave
router.post('/', authenticate, async (req, res) => {
  try {
    const { leave_id, leave_type, from_date, to_date, days, reason, department } = req.body;
    if (!leave_id || !leave_type || !from_date || !to_date)
      return res.status(400).json({ error: 'leave_id, leave_type, from_date, to_date are required' });

    const result = await db.query(
      `INSERT INTO leave_applications
         (leave_id, employee_name, department, leave_type, from_date, to_date, days, reason)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [leave_id, req.user.name, department || '', leave_type, from_date, to_date, days, reason || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505')
      return res.status(409).json({ error: 'Leave ID already exists' });
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/leaves/:id/manager-status
router.patch('/:id/manager-status', authenticate, requireRole('reportingManager', 'hr'), async (req, res) => {
  try {
    const { status } = req.body;
    if (!['pending','approved','denied'].includes(status))
      return res.status(400).json({ error: 'Invalid status' });

    const result = await db.query(
      'UPDATE leave_applications SET manager_status=$1 WHERE id=$2 RETURNING *',
      [status, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/leaves/:id/hr-status
router.patch('/:id/hr-status', authenticate, requireRole('hr'), async (req, res) => {
  try {
    const { status } = req.body;
    if (!['pending','approved','denied'].includes(status))
      return res.status(400).json({ error: 'Invalid status' });

    const result = await db.query(
      'UPDATE leave_applications SET hr_status=$1 WHERE id=$2 RETURNING *',
      [status, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/leaves/:id
router.delete('/:id', authenticate, requireRole('hr'), async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM leave_applications WHERE id=$1 RETURNING id',
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json({ deleted: result.rows[0].id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
