const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../config/db');

exports.register = async (req, res) => {
    const { name, email, password, role } = req.body;

    try {
        const hash = await bcrypt.hash(password, 10);
        const result = await db.query(
            `INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING id`,
            [name, email, hash, role]
        );
        res.status(201).json({ status: 'success', userId: result.rows[0].id });
    } catch (e) {
        if (e.code === '23505') {
            return res.status(400).json({ status: 'error', message: 'Email already exists' });
        }
        res.status(500).json({ status: 'error', message: e.message });
    }
};

exports.login = async (req, res) => {
    const { email, password } = req.body;

    // Support username-based login: if no '@' in input, treat as username and append '@kvm.edu'
    const lookupEmail = email.includes('@') ? email : `${email}@kvm.edu`;

    try {
        const result = await db.query(`SELECT id, password_hash, role FROM users WHERE email = $1`, [lookupEmail]);
        if (result.rows.length === 0) {
            return res.status(401).json({ status: 'error', message: 'Invalid credentials' });
        }

        const user = result.rows[0];
        const isValid = await bcrypt.compare(password, user.password_hash);
        
        if (!isValid) {
            return res.status(401).json({ status: 'error', message: 'Invalid credentials' });
        }

        const payload = { userId: user.id, role: user.role };
        const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });

        res.json({ status: 'success', token, role: user.role, userId: user.id });
    } catch (e) {
        res.status(500).json({ status: 'error', message: e.message });
    }
};

exports.resetPasswords = async (req, res) => {
    const { users } = req.body;
    if (!users || !Array.isArray(users)) {
        return res.status(400).json({ status: 'error', message: 'users array required' });
    }

    const results = [];
    for (const u of users) {
        try {
            const hash = await bcrypt.hash(u.newPassword, 10);
            const result = await db.query(
                `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE email = $2 RETURNING id`,
                [hash, u.email]
            );
            results.push({ email: u.email, status: result.rowCount > 0 ? 'updated' : 'not_found' });
        } catch (e) {
            results.push({ email: u.email, status: 'error', message: e.message });
        }
    }
    res.json({ status: 'success', results });
};
