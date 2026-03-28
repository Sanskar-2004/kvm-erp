require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function migrate() {
  try {
    const sql = fs.readFileSync(path.join(__dirname, 'src', 'db', 'fee_migration.sql'), 'utf8');
    await pool.query(sql);
    console.log('SUCCESS: fee_structure, student_fees, and alerts tables created');
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

migrate();
