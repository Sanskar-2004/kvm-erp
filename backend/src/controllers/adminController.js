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

        // Check for duplicate usernames (by email convention username@kvm.edu)
        const dupCheck = await client.query(
            `SELECT email FROM users WHERE email = ANY($1)`,
            [[`${student_username}@kvm.edu`, `${parent_username}@kvm.edu`]]
        );
        if (dupCheck.rows.length > 0) {
            await client.query('ROLLBACK');
            const dupes = dupCheck.rows.map(r => r.email.replace('@kvm.edu', ''));
            return res.status(409).json({ status: 'error', message: 'Username already exists', duplicates: dupes });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        // Create student user account
        const studentUserResult = await client.query(
            `INSERT INTO users (name, email, password_hash, role)
             VALUES ($1, $2, $3, 'student') RETURNING id`,
            [student_username, `${student_username}@kvm.edu`, hashedPassword]
        );
        const studentUserId = studentUserResult.rows[0].id;

        // Create parent user account (same password)
        const parentUserResult = await client.query(
            `INSERT INTO users (name, email, password_hash, role)
             VALUES ($1, $2, $3, 'parent') RETURNING id`,
            [parent_username, `${parent_username}@kvm.edu`, hashedPassword]
        );
        const parentUserId = parentUserResult.rows[0].id;

        // CRITICAL FIX: The parent_student_map has a foreign key to students(id).
        // Since the Flutter app syncs the full student *after* this API call returns,
        // we must insert a stub student record first, or Postgres throws a 500 FK error.
        await client.query(
            `INSERT INTO students (id, name, class_id, is_synced, created_at, updated_at)
             VALUES ($1, 'Pending Sync', 'Unknown', false, CURRENT_TIMESTAMP::TEXT, CURRENT_TIMESTAMP::TEXT)
             ON CONFLICT (id) DO NOTHING`,
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
            message: 'Student and parent accounts created successfully',
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
