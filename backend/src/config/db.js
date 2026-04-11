const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// Self-healing migration: Ensure schema is up to date on every startup
(async () => {
    try {
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id TEXT DEFAULT NULL');
        console.log('--- DB Schema Verified ---');
    } catch (e) {
        console.error('--- DB Auto-Migration Warning ---', e.message);
    }
})();

module.exports = {
  query: (text, params) => pool.query(text, params),
  getClient: () => pool.connect(),
};
