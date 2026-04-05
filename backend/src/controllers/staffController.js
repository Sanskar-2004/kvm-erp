const db = require('../config/db');
const bcrypt = require('bcrypt');

exports.createStaff = async (req, res) => {
    try {
        const { 
            id, name, phone, email, role, employee_code, department, 
            joining_date, salary, status, subject_specialization, 
            vehicle_assigned, can_login, device_id 
        } = req.body;

        await db.query('BEGIN'); // Start transaction

        let user_id = null;
        
        // Only spawn ERP user identity if toggle is authentically active
        if (can_login) {
            // Usually we'd take username via req.body, but for ERP let's use phone or unique employee_code or email
            let username = req.body.username || phone || email || employee_code;
            if (!username.includes('@')) {
                username = `${username}@kvm.edu`;
            }
            const rawPassword = req.body.password || 'kvmerp123';
            const hash = await bcrypt.hash(rawPassword, 10);
            
            // Insert into users strictly capturing SERIAL ID via RETURNING
            const userRes = await db.query(
                `INSERT INTO users (name, email, password_hash, role, device_id, is_synced, is_deleted)
                 VALUES ($1, $2, $3, $4, $5, true, 0) RETURNING id`,
                [name, username, hash, role, device_id || 'system']
            );
            user_id = userRes.rows[0].id;
        }

        // Create the core HR staff record linking identity if spawned
        await db.query(
            `INSERT INTO staff (id, name, phone, email, role, employee_code, department, joining_date, salary, status, subject_specialization, vehicle_assigned, can_login, user_id, device_id, is_synced, is_deleted, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, true, 0, NOW(), NOW())`,
            [
                id, name, phone, email, role, employee_code, department, 
                joining_date, salary, status, subject_specialization, 
                vehicle_assigned, can_login ? true : false, user_id, device_id || 'system'
            ]
        );

        await db.query('COMMIT');

        res.json({ status: 'success', message: 'Staff successfully created', user_id });
    } catch (e) {
        await db.query('ROLLBACK');
        console.error('[Create Staff Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

exports.getAllStaff = async (req, res) => {
    try {
        const result = await db.query("SELECT * FROM staff WHERE is_deleted = 0 ORDER BY created_at DESC");
        res.json({ status: 'success', data: result.rows });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
};
