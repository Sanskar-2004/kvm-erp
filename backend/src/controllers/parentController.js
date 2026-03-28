const db = require('../config/db');

// GET /api/parent/children/:parentId — Get all children for a parent (Sibling Feature)
exports.getChildren = async (req, res) => {
    try {
        const { parentId } = req.params;

        const result = await db.query(`
            SELECT s.id, s.name, s.class_id, s.roll_number, s.gender, s.status,
                   psm.relationship
            FROM parent_student_map psm
            JOIN students s ON s.id = psm.student_id
            WHERE psm.parent_id = $1 AND s.is_deleted = 0
            ORDER BY s.name
        `, [parentId]);

        res.json({ status: 'success', children: result.rows });
    } catch (e) {
        console.error('[Get Children Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// POST /api/parent/link — Link parent to student
exports.linkParentStudent = async (req, res) => {
    try {
        const { parent_id, student_id, relationship } = req.body;
        const id = `psm_${parent_id}_${student_id}`;

        await db.query(
            `INSERT INTO parent_student_map (id, parent_id, student_id, relationship)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (parent_id, student_id) DO NOTHING`,
            [id, parent_id, student_id, relationship || 'parent']
        );

        res.json({ status: 'success', message: 'Parent-student linked' });
    } catch (e) {
        console.error('[Link Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/parent/student-summary/:studentId — Full summary for one child
exports.getStudentSummary = async (req, res) => {
    try {
        const { studentId } = req.params;

        // Attendance percentage
        const attResult = await db.query(`
            SELECT 
                COUNT(*) AS total,
                SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) AS present
            FROM attendance
            WHERE student_id = $1 AND is_deleted = 0
        `, [studentId]);

        const total = parseInt(attResult.rows[0]?.total || 0);
        const present = parseInt(attResult.rows[0]?.present || 0);
        const attendancePercent = total > 0 ? ((present / total) * 100).toFixed(1) : '0.0';

        // Fee summary
        const feeResult = await db.query(`
            SELECT 
                COALESCE(SUM(amount_due), 0) AS total_due,
                COALESCE(SUM(amount_paid), 0) AS total_paid
            FROM student_fees
            WHERE student_id = $1 AND is_deleted = 0
        `, [studentId]);

        // Latest marks
        const marksResult = await db.query(`
            SELECT subject, marks_obtained, total_marks, exam_type, percentage, class_rank
            FROM marks
            WHERE student_id = $1 AND is_deleted = 0
            ORDER BY date DESC LIMIT 10
        `, [studentId]);

        // Alerts
        const alertsResult = await db.query(`
            SELECT id, message, is_read, created_at
            FROM alerts
            WHERE user_id = $1
            ORDER BY created_at DESC LIMIT 10
        `, [studentId]);

        res.json({
            status: 'success',
            data: {
                attendance: { total, present, percentage: attendancePercent },
                fees: feeResult.rows[0],
                marks: marksResult.rows,
                alerts: alertsResult.rows
            }
        });
    } catch (e) {
        console.error('[Student Summary Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};
