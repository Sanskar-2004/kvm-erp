require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

async function run() {
    try {
        const res = await pool.query('SELECT id, name, email, role FROM users ORDER BY id ASC');
        console.log('--- USERS IN DATABASE ---');
        console.table(res.rows);
    } catch (err) {
        console.error('Error fetching users:', err.message);
    } finally {
        await pool.end();
    }
}

run();
