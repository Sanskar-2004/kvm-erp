require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function migrate() {
  try {
    await pool.query("ALTER TABLE students ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'approved'");
    console.log('SUCCESS: status column added to students table');
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

migrate();
