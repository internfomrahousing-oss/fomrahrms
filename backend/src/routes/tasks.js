const router = require('express').Router();
const db     = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

// GET /api/tasks
router.get('/', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM tasks ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/tasks/my  — tasks assigned to current user
router.get('/my', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM tasks
       WHERE assigned_employee ILIKE $1
          OR $1 = ANY(team_members)
       ORDER BY created_at DESC`,
      [req.user.name]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/tasks
router.post('/', authenticate, requireRole('hr', 'reportingManager'), async (req, res) => {
  try {
    const {
      task_id, name, description, priority, start_date, due_date,
      weightage, assigned_employee, team_members, department, attachment,
    } = req.body;

    if (!task_id || !name || !start_date || !due_date)
      return res.status(400).json({ error: 'task_id, name, start_date, due_date are required' });

    const result = await db.query(
      `INSERT INTO tasks
         (task_id, name, description, priority, start_date, due_date,
          weightage, assigned_employee, team_members, department, attachment)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING *`,
      [task_id, name, description || '', priority || 'medium',
       start_date, due_date, weightage || 0,
       assigned_employee || '', team_members || [], department || '', attachment || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505')
      return res.status(409).json({ error: 'Task ID already exists' });
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/tasks/:id/status
router.patch('/:id/status', authenticate, async (req, res) => {
  try {
    const { status } = req.body;
    const valid = ['assigned','pending','inProgress','completed','delayed','rejected'];
    if (!valid.includes(status))
      return res.status(400).json({ error: 'Invalid status' });

    const result = await db.query(
      'UPDATE tasks SET status=$1 WHERE id=$2 RETURNING *',
      [status, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/tasks/:id
router.delete('/:id', authenticate, requireRole('hr', 'reportingManager'), async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM tasks WHERE id=$1 RETURNING id',
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
