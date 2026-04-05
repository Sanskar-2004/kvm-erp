const db = require('../config/db');

// POST /api/timetable — Create with clash detection
exports.createTimetableEntry = async (req, res) => {
    try {
        const { id, class_id, subject_id, teacher_id, teacher_name, day_of_week, start_time, end_time, subject, period_number } = req.body;

        // CLASH DETECTION: Check if teacher is already booked at this time
        // Excludes the current record (id) so editing an existing slot doesn't clash with itself
        const clash = await db.query(
            `SELECT id, class_id, subject FROM timetable 
             WHERE teacher_id = $1 AND day_of_week = $2 
             AND period_number = $3
             AND class_id != $4
             AND id != $5
             AND is_deleted = 0`,
            [teacher_id, day_of_week, period_number, class_id, id || '']
        );

        if (clash.rows.length > 0) {
            return res.status(409).json({
                status: 'conflict',
                message: `Teacher is already booked for ${clash.rows[0].subject} in Class ${clash.rows[0].class_id} during this time slot`,
                existingEntry: clash.rows[0]
            });
        }

        await db.query(
            `INSERT INTO timetable (id, class_id, subject_id, teacher_id, teacher_name, day_of_week, start_time, end_time, subject, period_number, device_id, is_synced, is_deleted, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, true, 0, NOW())
             ON CONFLICT (id) DO UPDATE SET
               class_id = EXCLUDED.class_id, subject = EXCLUDED.subject, teacher_id = EXCLUDED.teacher_id,
               day_of_week = EXCLUDED.day_of_week, start_time = EXCLUDED.start_time, end_time = EXCLUDED.end_time,
               updated_at = NOW()`,
            [id, class_id, subject_id, teacher_id, teacher_name, day_of_week, start_time, end_time, subject, period_number, req.user?.userId || 'system']
        );

        res.json({ status: 'success', message: 'Timetable entry created' });
    } catch (e) {
        console.error('[Timetable Create Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/timetable/:classId — Get timetable for a class
exports.getClassTimetable = async (req, res) => {
    try {
        const { classId } = req.params;
        const result = await db.query(
            `SELECT * FROM timetable WHERE class_id = $1 AND is_deleted = 0 ORDER BY day_of_week, period_number`,
            [classId]
        );
        res.json({ status: 'success', timetable: result.rows });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
};

// GET /api/timetable/teacher/:teacherId — Teacher's personal schedule
exports.getTeacherTimetable = async (req, res) => {
    try {
        const { teacherId } = req.params;
        const result = await db.query(
            `SELECT t.* FROM timetable t 
             JOIN staff s ON t.teacher_id = s.id 
             WHERE s.user_id = $1 AND t.is_deleted = 0 
             ORDER BY t.day_of_week, t.period_number`,
            [teacherId]
        );
        res.json({ status: 'success', timetable: result.rows });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
};
