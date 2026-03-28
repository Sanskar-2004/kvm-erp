require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function createTimetable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS timetable (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        subject TEXT,
        subject_id TEXT,
        teacher_id TEXT,
        teacher_name TEXT,
        day_of_week TEXT,
        start_time TEXT,
        end_time TEXT,
        period_number INTEGER DEFAULT 1,
        device_id TEXT,
        is_synced BOOLEAN DEFAULT TRUE,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT
      )
    `);
    console.log('SUCCESS: timetable table created');
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

createTimetable();
