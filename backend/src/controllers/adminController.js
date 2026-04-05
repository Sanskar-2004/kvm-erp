const db = require('../config/db');

// GET /api/admin/finance-summary — Admin financial overview
exports.getFinanceSummary = async (req, res) => {
    try {
        if (req.user.role !== 'admin') {
            return res.status(403).json({ status: 'error', message: 'Admin only' });
        }

        // Yearly totals
        const yearlyResult = await db.query(`
            SELECT 
                COALESCE(SUM(amount_due), 0) AS total_due,
                COALESCE(SUM(amount_paid), 0) AS total_paid,
                COALESCE(SUM(amount_due - amount_paid - discount_amount), 0) AS total_pending
            FROM student_fees
            WHERE academic_year = $1 AND is_deleted = 0
        `, ['2026-2027']);

        // Recent 10 transactions
        const recentResult = await db.query(`
            SELECT sf.id, sf.student_id, s.name AS student_name, sf.month,
                   sf.amount_paid, sf.payment_method, sf.paid_date, sf.status
            FROM student_fees sf
            LEFT JOIN students s ON s.id = sf.student_id
            WHERE sf.status IN ('PAID', 'PARTIAL') AND sf.is_deleted = 0
            ORDER BY sf.paid_date DESC
            LIMIT 10
        `);

        // Unpaid students count
        const unpaidResult = await db.query(`
            SELECT COUNT(DISTINCT student_id) AS unpaid_count
            FROM student_fees
            WHERE status = 'UNPAID' AND is_deleted = 0
        `);

        res.json({
            status: 'success',
            data: {
                yearly: yearlyResult.rows[0],
                recentTransactions: recentResult.rows,
                unpaidStudentCount: unpaidResult.rows[0]?.unpaid_count || 0
            }
        });
    } catch (e) {
        console.error('[Finance Summary Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/admin/class-ranks/:classId/:examType — Server-side rank calculation
exports.calculateClassRanks = async (req, res) => {
    try {
        const { classId, examType } = req.params;

        // Proper RANK() OVER window function for tie-safe ranking
        const result = await db.query(`
            SELECT 
                sub.student_id,
                sub.student_name,
                sub.total_obtained,
                sub.total_max,
                sub.percentage,
                RANK() OVER (ORDER BY sub.percentage DESC) AS rank
            FROM (
                SELECT m.student_id, s.name AS student_name,
                       SUM(m.marks_obtained) AS total_obtained,
                       SUM(m.total_marks) AS total_max,
                       ROUND((SUM(m.marks_obtained)::NUMERIC / NULLIF(SUM(m.total_marks), 0)) * 100, 2) AS percentage
                FROM marks m
                JOIN students s ON s.id = m.student_id
                WHERE s.class_id = $1 AND m.exam_type = $2 AND m.is_deleted = 0
                GROUP BY m.student_id, s.name
            ) sub
            ORDER BY sub.percentage DESC
        `, [classId, examType]);

        res.json({ status: 'success', rankings: result.rows });
    } catch (e) {
        console.error('[Rank Calculation Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/admin/due-fees — All unpaid students with grand total
exports.getDueFees = async (req, res) => {
    try {
        const result = await db.query(`
            SELECT sf.student_id, s.name AS student_name, s.class_id,
                   SUM(sf.amount_due - sf.amount_paid - COALESCE(sf.discount_amount, 0)) AS total_due
            FROM student_fees sf
            JOIN students s ON s.id = sf.student_id
            WHERE sf.status IN ('UNPAID', 'PARTIAL') AND sf.is_deleted = 0
            GROUP BY sf.student_id, s.name, s.class_id
            HAVING SUM(sf.amount_due - sf.amount_paid - COALESCE(sf.discount_amount, 0)) > 0
            ORDER BY total_due DESC
        `);

        const grandTotal = result.rows.reduce((sum, r) => sum + parseFloat(r.total_due || 0), 0);

        res.json({
            status: 'success',
            students: result.rows,
            grandTotal: grandTotal
        });
    } catch (e) {
        console.error('[Due Fees Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};
