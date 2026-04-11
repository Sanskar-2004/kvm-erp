const db = require('../config/db');
const bcrypt = require('bcrypt');

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

// POST /api/admin/create-student-accounts — Create student + parent login accounts
exports.createStudentAccounts = async (req, res) => {
    let client;
    try {
        const { student_id, student_username, parent_username, password } = req.body;

        if (!student_id || !student_username || !parent_username || !password) {
            return res.status(400).json({ status: 'error', message: 'Missing required fields' });
        }

        client = await db.getClient();
        await client.query('BEGIN');

        const hashedPassword = await bcrypt.hash(password, 10);
        const studentEmail = `${student_username}@kvm.edu`;
        const parentEmail = `${parent_username}@kvm.edu`;

        let studentUserId;
        let parentUserId;

        // --- 1. Handle Student Account ---
        const existingStudent = await client.query(
            `SELECT id, is_deleted, role FROM users WHERE email = $1`,
            [studentEmail]
        );

        if (existingStudent.rows.length > 0) {
            const user = existingStudent.rows[0];
            if (user.role === 'student' && user.is_deleted === 1) {
                // Revive the soft-deleted student account
                await client.query(
                    `UPDATE users SET password_hash = $1, student_id = $2, is_deleted = 0, updated_at = CURRENT_TIMESTAMP::TEXT WHERE id = $3`,
                    [hashedPassword, student_id, user.id]
                );
                studentUserId = user.id;
            } else {
                // Active conflict
                await client.query('ROLLBACK');
                return res.status(409).json({ status: 'error', message: 'Username already exists', duplicates: [student_username] });
            }
        } else {
            // Insert fresh student
            const studentUserResult = await client.query(
                `INSERT INTO users (name, email, password_hash, role, student_id)
                 VALUES ($1, $2, $3, 'student', $4) RETURNING id`,
                [student_username, studentEmail, hashedPassword, student_id]
            );
            studentUserId = studentUserResult.rows[0].id;
        }

        // --- 2. Handle Parent Account (Sibling Feature) ---
        const existingParent = await client.query(
            `SELECT id, role FROM users WHERE email = $1`,
            [parentEmail]
        );

        if (existingParent.rows.length > 0) {
            const user = existingParent.rows[0];
            if (user.role === 'parent') {
                // Parent already exists (Adding a Sibling!) -> Re-use Account
                parentUserId = user.id;
                // Update their password to match the new one just in case
                await client.query(
                    `UPDATE users SET password_hash = $1, is_deleted = 0, updated_at = CURRENT_TIMESTAMP::TEXT WHERE id = $2`,
                    [hashedPassword, parentUserId]
                );
            } else {
                await client.query('ROLLBACK');
                return res.status(409).json({ status: 'error', message: 'Username already taken by a non-parent', duplicates: [parent_username] });
            }
        } else {
            // Insert fresh parent
            const parentUserResult = await client.query(
                `INSERT INTO users (name, email, password_hash, role)
                 VALUES ($1, $2, $3, 'parent') RETURNING id`,
                [parent_username, parentEmail, hashedPassword]
            );
            parentUserId = parentUserResult.rows[0].id;
        }

        // --- 3. Manage Student Stub & Map ---
        // Insert a stub student record to safely satisfy the Foreign Key constraint for the parent_student_map
        // before the heavy sync engine pushes the real student details to PostgreSQL.
        await client.query(
            `INSERT INTO students (id, name, class_id, is_synced, created_at, updated_at)
             VALUES ($1, 'Pending Sync', 'Unknown', false, CURRENT_TIMESTAMP::TEXT, CURRENT_TIMESTAMP::TEXT)
             ON CONFLICT (id) DO UPDATE SET is_deleted = 0`,
            [student_id]
        );

        // Link parent -> student in parent_student_map
        const mapId = `psm_${parentUserId}_${student_id}`;
        await client.query(
            `INSERT INTO parent_student_map (id, parent_id, student_id, relationship)
             VALUES ($1, $2, $3, 'parent')
             ON CONFLICT (parent_id, student_id) DO NOTHING`,
            [mapId, parentUserId, student_id]
        );

        await client.query('COMMIT');

        return res.status(201).json({
            status: 'success',
            message: 'Accounts processed successfully',
            data: { student_user_id: studentUserId, parent_user_id: parentUserId }
        });
    } catch (e) {
        if (client) await client.query('ROLLBACK');
        console.error('[Create Student Accounts Error]', e);
        return res.status(500).json({ status: 'error', message: e.message });
    } finally {
        if (client) client.release();
    }
};

// POST /api/admin/nuke-database
exports.nukeDatabase = async (req, res) => {
    let client;
    try {
        const { password } = req.body;
        if (!password) {
            return res.status(400).json({ status: 'error', message: 'Password is required to wipe the database.' });
        }

        const adminId = req.user.userId;

        client = await db.getClient();
        await client.query("BEGIN");

        // Verify Admin Password
        const adminResult = await client.query(`SELECT password_hash FROM users WHERE id = $1 AND role = 'admin'`, [adminId]);
        if (adminResult.rows.length === 0) {
            return res.status(401).json({ status: 'error', message: 'Unauthorized. You must be an admin to perform this action.' });
        }
        
        const isMatch = await bcrypt.compare(password, adminResult.rows[0].password_hash);
        if (!isMatch) {
            return res.status(401).json({ status: 'error', message: 'Incorrect password.' });
        }

        
        const safeDelete = async (table) => {
            try { await client.query(`DELETE FROM ${table}`); } 
            catch (e) { /* Ignore missing tables */ }
        };

        await safeDelete("sync_logs");
        await safeDelete("parent_student_map");
        await safeDelete("attendance");
        await safeDelete("marks");
        await safeDelete("student_fees");
        await safeDelete("fees");
        await safeDelete("timetable");
        await safeDelete("staff_assignments");
        await safeDelete("subjects");
        await safeDelete("fee_structure");
        await safeDelete("alerts");
        await safeDelete("students");
        await safeDelete("staff");
        
        await client.query("DELETE FROM users WHERE role != 'admin'");
        
        await client.query("COMMIT");
        res.json({ status: 'success', message: 'DATABASE FULLY WIPED EXCEPT ADMIN.' });
    } catch (e) {
        if (client) await client.query("ROLLBACK");
        res.status(500).json({ status: 'error', message: e.message });
    } finally {
        if (client) client.release();
    }
};
