require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function migrate() {
  try {
    console.log('Running migration: Adding student_id to users...');
    await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id TEXT DEFAULT NULL');
    console.log('Migration SUCCESSFUL.');
  } catch (e) {
    console.error('Migration FAILED:', e);
  } finally {
    await pool.end();
  }
}

migrate();
