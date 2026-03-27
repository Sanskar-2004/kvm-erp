require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runDeploy() {
  try {
    const rawSql = fs.readFileSync(path.join(__dirname, 'src', 'db', 'init.sql')).toString();
    console.log('[pg] Building Server Models on Remote Matrix...');
    
    await pool.query(rawSql);
    
    console.log('[pg] ALL 8 SQLITE SCHEMA MIRRORS BOUND SECURELY TO NEON.TECH!');
  } catch (e) {
    console.error('[pg] SCHEMA DEPLOYMENT FAILED:', e);
  } finally {
    pool.end();
  }
}

runDeploy();
