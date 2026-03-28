require('dotenv').config();
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const users = [
  { name: 'Admin User',      email: 'admin@kvm.edu',      password: 'admin123',      role: 'admin' },
  { name: 'Teacher User',    email: 'teacher@kvm.edu',    password: 'teacher123',    role: 'teacher' },
  { name: 'Parent User',     email: 'parent@kvm.edu',     password: 'parent123',     role: 'parent' },
  { name: 'Student User',    email: 'student@kvm.edu',    password: 'student123',    role: 'student' },
  { name: 'Accountant User', email: 'accountant@kvm.edu', password: 'accountant123', role: 'accountant' },
];

async function seed() {
  for (const u of users) {
    try {
      const hash = await bcrypt.hash(u.password, 10);
      await pool.query(
        `INSERT INTO users (name, email, password_hash, role, created_at, updated_at)
         VALUES ($1, $2, $3, $4, NOW(), NOW())
         ON CONFLICT (email) DO NOTHING`,
        [u.name, u.email, hash, u.role]
      );
      console.log(`✅ ${u.role.toUpperCase()} → ${u.email} / ${u.password}`);
    } catch (e) {
      console.error(`❌ ${u.role}: ${e.message}`);
    }
  }
  await pool.end();
  console.log('\nDone! Use these credentials to login.');
}

seed();
