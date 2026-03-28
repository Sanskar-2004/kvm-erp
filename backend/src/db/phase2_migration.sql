-- KVM ERP Phase 2: Schema Expansion
-- parent_student_map, staff_type, timetable upgrade, marks upgrade, fee upgrades

-- 1. Add staff_type to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS staff_type TEXT DEFAULT NULL;
-- staff_type: 'Teacher', 'Accountant', 'Driver', 'Janitor', NULL

-- 2. Parent-Student mapping (Sibling Feature)
CREATE TABLE IF NOT EXISTS parent_student_map (
    id TEXT PRIMARY KEY,
    parent_id INTEGER NOT NULL REFERENCES users(id),
    student_id TEXT NOT NULL REFERENCES students(id),
    relationship TEXT DEFAULT 'parent',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT,
    UNIQUE(parent_id, student_id)
);

-- 3. Upgrade student_fees with discount + payment method
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS discount_amount REAL DEFAULT 0.0;
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS discount_reason TEXT DEFAULT NULL;
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT NULL;
-- payment_method: 'Cash', 'Cheque', 'UPI', 'Bank Transfer'

-- 4. Subjects master table
CREATE TABLE IF NOT EXISTS subjects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT
);

-- 5. Upgraded timetable table (drop-and-recreate if empty, else alter)
-- Using new columns approach since data may exist
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS subject_id TEXT DEFAULT NULL;
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS start_time TEXT DEFAULT NULL;
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS end_time TEXT DEFAULT NULL;
ALTER TABLE timetable ADD COLUMN IF NOT EXISTS day_of_week TEXT DEFAULT NULL;

-- 6. Upgrade marks with exam_type enum and subject_id  
ALTER TABLE marks ADD COLUMN IF NOT EXISTS subject_id TEXT DEFAULT NULL;
ALTER TABLE marks ADD COLUMN IF NOT EXISTS class_rank INTEGER DEFAULT NULL;
ALTER TABLE marks ADD COLUMN IF NOT EXISTS percentage REAL DEFAULT NULL;

-- 7. Add students missing columns for full model
ALTER TABLE students ADD COLUMN IF NOT EXISTS roll_number TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS parent_name TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS parent_phone TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS date_of_birth TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS gender TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS admission_date TEXT DEFAULT '';
ALTER TABLE students ADD COLUMN IF NOT EXISTS email TEXT DEFAULT NULL;
ALTER TABLE students ADD COLUMN IF NOT EXISTS profile_image_url TEXT DEFAULT NULL;
