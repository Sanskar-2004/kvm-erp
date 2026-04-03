require('dotenv').config();
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const users = [
  { name: 'Admin User',      username: 'admin',      email: 'admin@kvm.edu',      password: 'admin',      role: 'admin' },
  { name: 'Teacher User',    username: 'teacher',    email: 'teacher@kvm.edu',    password: 'teacher',    role: 'teacher' },
  { name: 'Parent User',     username: 'parent',     email: 'parent@kvm.edu',     password: 'parent',     role: 'parent' },
  { name: 'Student User',    username: 'student',    email: 'student@kvm.edu',    password: 'student',    role: 'student' },
  { name: 'Accountant User', username: 'accountant', email: 'accountant@kvm.edu', password: 'accountant', role: 'accountant' },
];

async function seed() {
  for (const u of users) {
    try {
      const hash = await bcrypt.hash(u.password, 10);
      await pool.query(
        `INSERT INTO users (name, email, password_hash, role, created_at, updated_at)
         VALUES ($1, $2, $3, $4, NOW(), NOW())
         ON CONFLICT (email) DO UPDATE SET password_hash = $3, updated_at = NOW()`,
        [u.name, u.email, hash, u.role]
      );
      console.log(`✅ ${u.role.toUpperCase()} → username: ${u.username} / password: ${u.password}`);
    } catch (e) {
      console.error(`❌ ${u.role}: ${e.message}`);
    }
  }
  await pool.end();
  console.log('\nDone! Use these credentials to login.');
}

seed();
