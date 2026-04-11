const { Pool } = require('pg');
require('dotenv').config({path: '.env'});

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runHealthProbe() {
    console.log("--- KVM ERP HEALTH PROBE ---");
    const client = await pool.connect();
    try {
        // 1. Check Tables Existence
        console.log("\n[1/3] CHECKING TABLES...");
        const tablesToCheck = [
            "users", "staff", "students", "attendance", "marks", "fees", 
            "staff_assignments", "sync_logs", "parent_student_map", 
            "subjects", "fee_structure", "student_fees", "alerts"
        ];
        
        const tableCheckRes = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);
        const existingTables = tableCheckRes.rows.map(r => r.table_name.toLowerCase());
        
        tablesToCheck.forEach(t => {
            if (existingTables.includes(t)) {
                console.log(`✅ Table '${t}' exists.`);
            } else {
                console.warn(`⚠️ Table '${t}' MISSING in database!`);
            }
        });

        // 2. Verify Admin User
        console.log("\n[2/3] VERIFYING ADMIN USER...");
        const adminRes = await client.query("SELECT id, name, email, role FROM users WHERE role = 'admin' LIMIT 1");
        if (adminRes.rows.length > 0) {
            console.log(`✅ Found Admin: ${adminRes.rows[0].name} (${adminRes.rows[0].email})`);
        } else {
            console.error("❌ NO ADMIN USER FOUND!");
        }

        // 3. Test nuke query logic (dry run)
        console.log("\n[3/3] PROBING NUKE LOGIC...");
        // This is safe, just verifying count
        const totalUsers = await client.query("SELECT count(*) FROM users");
        const totalOtherUsers = await client.query("SELECT count(*) FROM users WHERE role != 'admin'");
        console.log(`📊 Current Users: ${totalUsers.rows[0].count}`);
        console.log(`📉 Non-Admin Users to be wiped: ${totalOtherUsers.rows[0].count}`);

        console.log("\n--- PROBE COMPLETE ---");
    } catch (e) {
        console.error("❌ PROBE FAILED:", e.message);
    } finally {
        client.release();
        pool.end();
    }
}

runHealthProbe();
