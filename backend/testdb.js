const { Pool } = require('pg');
require('dotenv').config({path: 'backend/.env'});
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function test() {
  try {
    await pool.query("BEGIN");
    console.log("Creating student...");
    const s = await pool.query("INSERT INTO users (name, email, password_hash, role) VALUES ('teststudent', 'teststudent' || Math.random() || '@kvm.edu', 'hash', 'student') RETURNING id");
    console.log("Creating parent...");
    const p = await pool.query("INSERT INTO users (name, email, password_hash, role) VALUES ('testparent', 'testparent' || Math.random() || '@kvm.edu', 'hash', 'parent') RETURNING id");
    console.log("Linking map...");
    await pool.query("INSERT INTO parent_student_map (id, parent_id, student_id, relationship) VALUES ('map_test', $1, 'mock_student_id', 'parent')", [p.rows[0].id]);
    await pool.query("ROLLBACK");
    console.log('SUCCESS');
  } catch (e) {
    await pool.query("ROLLBACK");
    console.error('DB ERROR:', e.message);
  } finally {
    pool.end();
  }
}
test();
