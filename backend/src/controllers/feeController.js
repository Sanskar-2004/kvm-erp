const db = require('../config/db');

// GET /api/fees/:studentId/:year — 12-month fee ledger for a student
exports.getStudentFees = async (req, res) => {
    try {
        const { studentId, year } = req.params;

        const result = await db.query(
            `SELECT * FROM student_fees 
             WHERE student_id = $1 AND academic_year = $2 
             ORDER BY month ASC`,
            [studentId, year]
        );

        res.json({
            status: 'success',
            fees: result.rows
        });
    } catch (e) {
        console.error('[Get Fees Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// PUT /api/fees/:id — Update a fee record (accountant records payment)
exports.updateFee = async (req, res) => {
    try {
        const { id } = req.params;
        const { amount_paid, status, paid_date } = req.body;

        const result = await db.query(
            `UPDATE student_fees 
             SET amount_paid = $1, status = $2, paid_date = $3, updated_at = NOW()
             WHERE id = $4
             RETURNING *`,
            [amount_paid, status, paid_date || new Date().toISOString(), id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ status: 'error', message: 'Fee record not found' });
        }

        res.json({
            status: 'success',
            message: 'Fee updated successfully',
            fee: result.rows[0]
        });
    } catch (e) {
        console.error('[Update Fee Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// POST /api/fees/generate/:studentId — Generate 12-month fee records
exports.generateFees = async (req, res) => {
    try {
        const { studentId } = req.params;
        const { academic_year, monthly_amount } = req.body;

        const records = [];
        for (let month = 1; month <= 12; month++) {
            const id = `${studentId}_${academic_year}_${month}`;
            const result = await db.query(
                `INSERT INTO student_fees (id, student_id, academic_year, month, amount_due, amount_paid, status, created_at, updated_at)
                 VALUES ($1, $2, $3, $4, $5, 0, 'UNPAID', NOW(), NOW())
                 ON CONFLICT (student_id, academic_year, month) DO NOTHING
                 RETURNING *`,
                [id, studentId, academic_year, month, monthly_amount]
            );
            if (result.rows.length > 0) records.push(result.rows[0]);
        }

        res.json({
            status: 'success',
            message: `Generated ${records.length} fee records`,
            fees: records
        });
    } catch (e) {
        console.error('[Generate Fees Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// POST /api/alerts — Create an alert for parent/student
exports.createAlert = async (req, res) => {
    try {
        const { user_id, message } = req.body;
        const id = `alert_${Date.now()}`;

        await db.query(
            `INSERT INTO alerts (id, user_id, message) VALUES ($1, $2, $3)`,
            [id, user_id, message]
        );

        res.json({ status: 'success', message: 'Alert sent' });
    } catch (e) {
        console.error('[Alert Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/alerts/:userId — Get alerts for a user
exports.getAlerts = async (req, res) => {
    try {
        const { userId } = req.params;

        const result = await db.query(
            `SELECT * FROM alerts WHERE user_id = $1 ORDER BY created_at DESC`,
            [userId]
        );

        res.json({ status: 'success', alerts: result.rows });
    } catch (e) {
        console.error('[Get Alerts Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};
