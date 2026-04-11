const { Pool } = require('pg');
require('dotenv').config({path: '.env'});

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function wipeDatabase() {
    console.log("Starting full database wipe (except Admin)...");
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        
        // Delete child tables first to avoid foreign key violations
        console.log("Wiping child tables...");
        await client.query("DELETE FROM sync_logs");
        await client.query("DELETE FROM parent_student_map");
        await client.query("DELETE FROM attendance");
        await client.query("DELETE FROM marks");
        await client.query("DELETE FROM student_fees");
        await client.query("DELETE FROM fees");
        await client.query("DELETE FROM timetable");
        await client.query("DELETE FROM staff_assignments");
        
        // Delete master tables
        console.log("Wiping master tables...");
        await client.query("DELETE FROM students");
        await client.query("DELETE FROM staff");
        
        // Delete all users except admin
        console.log("Wiping non-admin users...");
        await client.query("DELETE FROM users WHERE role != 'admin'");
        
        await client.query("COMMIT");
        console.log("✅ DATABASE WIPED SUCCESSFULLY!");
    } catch (e) {
        await client.query("ROLLBACK");
        console.error("❌ ERROR WIPING DATABASE:", e.message);
    } finally {
        client.release();
        pool.end();
    }
}

wipeDatabase();
