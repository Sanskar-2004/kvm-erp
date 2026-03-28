const db = require('../config/db');

// PATCH /api/students/:id/status — Admin approves or rejects admission
exports.updateStudentStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body; // "approved" or "rejected"

        if (!['approved', 'rejected', 'pending'].includes(status)) {
            return res.status(400).json({ status: 'error', message: 'Invalid status. Must be: approved, rejected, or pending' });
        }

        // Only admins can approve/reject
        if (req.user.role !== 'admin') {
            return res.status(403).json({ status: 'error', message: 'Only admins can approve/reject admissions' });
        }

        const result = await db.query(
            `UPDATE students SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
            [status, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ status: 'error', message: 'Student not found' });
        }

        res.json({
            status: 'success',
            message: `Student ${status} successfully`,
            student: result.rows[0]
        });

    } catch (e) {
        console.error('[Student Status Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/students/pending — Admin fetches all pending admissions
exports.getPendingAdmissions = async (req, res) => {
    try {
        const result = await db.query(
            `SELECT * FROM students WHERE status = 'pending' AND is_deleted = false ORDER BY created_at DESC`
        );

        res.json({
            status: 'success',
            students: result.rows
        });

    } catch (e) {
        console.error('[Pending Admissions Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};
