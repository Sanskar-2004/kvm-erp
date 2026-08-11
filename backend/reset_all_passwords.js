require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

async function reset() {
    try {
        const hashAdmin = await bcrypt.hash('admin', 10);
        const hashTeacher = await bcrypt.hash('teacher', 10);
        const hashAccountant = await bcrypt.hash('accountant', 10);
        const hashStudent = await bcrypt.hash('student', 10);
        const hashParent = await bcrypt.hash('parent', 10);

        await pool.query(`UPDATE users SET password_hash = $1 WHERE role = 'admin'`, [hashAdmin]);
        await pool.query(`UPDATE users SET password_hash = $1 WHERE role = 'teacher'`, [hashTeacher]);
        await pool.query(`UPDATE users SET password_hash = $1 WHERE role = 'accountant'`, [hashAccountant]);
        await pool.query(`UPDATE users SET password_hash = $1 WHERE role = 'student'`, [hashStudent]);
        await pool.query(`UPDATE users SET password_hash = $1 WHERE role = 'parent'`, [hashParent]);

        console.log('✅ All database user passwords have been successfully reset to standard role passwords!');
    } catch (err) {
        console.error('Error resetting passwords:', err.message);
    } finally {
        await pool.end();
    }
}

reset();
