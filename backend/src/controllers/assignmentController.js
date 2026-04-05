const db = require('../config/db');

exports.createAssignment = async (req, res) => {
    try {
        const { id, staff_id, class_id, subject, academic_year, max_periods_per_day, max_periods_per_week, is_class_teacher, device_id } = req.body;
        
        // Ensure no duplicate assignment for exact same class + subject for the same teacher
        const existing = await db.query(
            `SELECT id FROM staff_assignments WHERE staff_id = $1 AND class_id = $2 AND subject = $3 AND is_deleted = 0`,
            [staff_id, class_id, subject]
        );

        if (existing.rows.length > 0) {
            return res.status(409).json({ status: 'conflict', message: 'Staff is already assigned to this class and subject.'});
        }

        await db.query(
            `INSERT INTO staff_assignments (id, staff_id, class_id, subject, academic_year, max_periods_per_day, max_periods_per_week, is_class_teacher, device_id, is_synced, is_deleted, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, 0, NOW(), NOW())`,
            [id, staff_id, class_id, subject, academic_year || '2026-27', max_periods_per_day || 6, max_periods_per_week || 30, is_class_teacher ? true : false, device_id || 'system']
        );

        res.json({ status: 'success', message: 'Staff assignment created' });
    } catch (e) {
        console.error('[Assignment Create Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

exports.getAssignments = async (req, res) => {
    try {
        const { class_id, staff_id } = req.query;
        let query = `SELECT sa.*, s.name as staff_name, s.role, s.phone 
                     FROM staff_assignments sa
                     JOIN staff s ON sa.staff_id = s.id
                     WHERE sa.is_deleted = 0`;
        const values = [];

        if (class_id) {
            values.push(class_id);
            query += ` AND sa.class_id = $${values.length}`;
        }
        if (staff_id) {
            values.push(staff_id);
            query += ` AND sa.staff_id = $${values.length}`;
        }

        query += ` ORDER BY s.name ASC`;
        
        const result = await db.query(query, values);
        res.json({ status: 'success', assignments: result.rows });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
};

exports.deleteAssignment = async (req, res) => {
    try {
        const { id } = req.params;
        await db.query(
            `UPDATE staff_assignments SET is_deleted = 1, is_synced = false, updated_at = NOW() WHERE id = $1`,
            [id]
        );
        res.json({ status: 'success', message: 'Assignment deleted' });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
};
