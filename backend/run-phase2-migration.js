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
    const sql = fs.readFileSync(path.join(__dirname, 'src', 'db', 'phase2_migration.sql'), 'utf8');
    
    // Split by semicolons and run each statement (some ALTER TABLE may fail gracefully)
    const statements = sql.split(';').filter(s => s.trim().length > 0);
    let success = 0;
    let skipped = 0;
    
    for (const stmt of statements) {
      try {
        await pool.query(stmt);
        success++;
      } catch (e) {
        // Column already exists or table already exists = skip
        if (e.message.includes('already exists') || e.message.includes('duplicate')) {
          skipped++;
        } else {
          console.error(`WARN: ${e.message.substring(0, 80)}`);
          skipped++;
        }
      }
    }
    
    console.log(`SUCCESS: ${success} statements executed, ${skipped} skipped (already exist)`);
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

migrate();
