const router = require('express').Router();
const db     = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

// GET /api/employees
router.get('/', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM employees ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/employees/:id
router.get('/:id', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM employees WHERE id = $1',
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/employees
router.post('/', authenticate, requireRole('hr', 'reportingManager'), async (req, res) => {
  try {
    const {
      employee_id, name, email, mobile, department, designation,
      manager, joining_date, salary, address, blood_group,
      bank_account, ifsc, emergency_name, emergency_phone, documents,
    } = req.body;

    if (!employee_id || !name)
      return res.status(400).json({ error: 'employee_id and name are required' });

    const result = await db.query(
      `INSERT INTO employees
         (employee_id, name, email, mobile, department, designation, manager,
          joining_date, salary, address, blood_group, bank_account, ifsc,
          emergency_name, emergency_phone, documents)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
       RETURNING *`,
      [employee_id, name, email, mobile, department, designation, manager,
       joining_date || null, salary || null, address, blood_group,
       bank_account, ifsc, emergency_name, emergency_phone, documents]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505')
      return res.status(409).json({ error: 'Employee ID already exists' });
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT /api/employees/:id
router.put('/:id', authenticate, requireRole('hr', 'reportingManager'), async (req, res) => {
  try {
    const {
      name, email, mobile, department, designation, manager,
      joining_date, salary, address, blood_group, bank_account,
      ifsc, emergency_name, emergency_phone, documents,
    } = req.body;

    const result = await db.query(
      `UPDATE employees SET
         name=$1, email=$2, mobile=$3, department=$4, designation=$5,
         manager=$6, joining_date=$7, salary=$8, address=$9,
         blood_group=$10, bank_account=$11, ifsc=$12,
         emergency_name=$13, emergency_phone=$14, documents=$15
       WHERE id=$16 RETURNING *`,
      [name, email, mobile, department, designation, manager,
       joining_date || null, salary || null, address, blood_group,
       bank_account, ifsc, emergency_name, emergency_phone, documents,
       req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/employees/:id
router.delete('/:id', authenticate, requireRole('hr'), async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM employees WHERE id=$1 RETURNING id',
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
