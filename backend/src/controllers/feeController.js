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
        const { academic_year, monthly_amount, start_month = 1, end_month = 12 } = req.body;

        const records = [];
        let currentMonth = parseInt(start_month);
        const targetEndMonth = parseInt(end_month);

        while (true) {
            const id = `${studentId}_${academic_year}_${currentMonth}`;
            const result = await db.query(
                `INSERT INTO student_fees (id, student_id, academic_year, month, amount_due, amount_paid, status, created_at, updated_at)
                 VALUES ($1, $2, $3, $4, $5, 0, 'UNPAID', NOW(), NOW())
                 ON CONFLICT (student_id, academic_year, month) DO NOTHING
                 RETURNING *`,
                [id, studentId, academic_year, currentMonth, monthly_amount]
            );
            if (result.rows.length > 0) records.push(result.rows[0]);

            if (currentMonth === targetEndMonth) break;
            currentMonth = (currentMonth % 12) + 1;
            
            // Safety break to prevent infinite loops if misconfigured
            if (records.length > 12) break;
        }

        const totalResult = await db.query(
            'SELECT COUNT(*) FROM student_fees WHERE student_id = $1 AND academic_year = $2',
            [studentId, academic_year]
        );

        res.json({
            status: 'success',
            message: `Generated ${records.length} new fee records. Total records for ${academic_year}: ${totalResult.rows[0].count}`,
            total_records: totalResult.rows[0].count,
            new_records: records.length
        });
    } catch (e) {
        console.error('[Generate Fees Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// POST /api/alerts — Create an alert for parent/student
exports.createAlert = async (req, res) => {
    try {
        let { user_id, message } = req.body;
        const id = `alert_${Date.now()}`;

        // If user_id is a UUID (starts with "std_" or just a long string), resolve to numeric ID
        const isUuid = user_id.toString().length > 10;
        if (isUuid) {
            const userRes = await db.query('SELECT id FROM users WHERE student_id = $1', [user_id]);
            if (userRes.rows.length > 0) {
                user_id = userRes.rows[0].id;
            }
        }

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
