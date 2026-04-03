// Quick seed script that calls the Render backend directly
// This avoids needing direct DB access from your machine

const BASE = 'https://kvm-erp.onrender.com/api';

const users = [
  { name: 'Admin User',      email: 'admin@kvm.edu',      password: 'admin',      role: 'admin' },
  { name: 'Teacher User',    email: 'teacher@kvm.edu',     password: 'teacher',    role: 'teacher' },
  { name: 'Parent User',     email: 'parent@kvm.edu',      password: 'parent',     role: 'parent' },
  { name: 'Student User',    email: 'student@kvm.edu',     password: 'student',    role: 'student' },
  { name: 'Accountant User', email: 'accountant@kvm.edu',  password: 'accountant', role: 'accountant' },
];

async function reseed() {
  // First, login as admin with OLD password to get a token
  let token;
  try {
    const loginRes = await fetch(`${BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'admin@kvm.edu', password: 'admin123' }),
    });
    const loginData = await loginRes.json();
    token = loginData.token;
    console.log('✅ Logged in with old admin credentials');
  } catch (e) {
    console.error('❌ Cannot login as admin:', e.message);
    return;
  }

  // Re-register each user (the register endpoint hashes the password)
  for (const u of users) {
    try {
      const res = await fetch(`${BASE}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(u),
      });
      const data = await res.json();
      if (res.status === 400 && data.message === 'Email already exists') {
        console.log(`⚠️  ${u.role} already exists — need direct DB update`);
      } else {
        console.log(`✅ ${u.role}: ${data.status}`);
      }
    } catch (e) {
      console.error(`❌ ${u.role}: ${e.message}`);
    }
  }
}

reseed();
