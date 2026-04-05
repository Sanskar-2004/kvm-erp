const { Pool } = require('pg');
require('dotenv').config({ path: 'backend/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  const query = `
    CREATE TABLE IF NOT EXISTS staff_assignments (
        id TEXT PRIMARY KEY,
        staff_id TEXT NOT NULL REFERENCES staff(id),
        class_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        academic_year TEXT NOT NULL DEFAULT '2026-27',
        max_periods_per_day INTEGER DEFAULT 6,
        max_periods_per_week INTEGER DEFAULT 30,
        is_class_teacher BOOLEAN DEFAULT false,
        device_id TEXT,
        is_synced BOOLEAN DEFAULT TRUE,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
  `;
  try {
    await pool.query(query);
    console.log('staff_assignments table created successfully.');
  } catch (err) {
    console.error('Error creating staff_assignments table:', err);
  } finally {
    pool.end();
  }
}

run();
