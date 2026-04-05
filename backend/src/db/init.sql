-- KVM ERP PostgreSQL Master Schema

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'teacher', 'student', 'parent', 'accountant')),
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT
);

CREATE TABLE IF NOT EXISTS staff (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role TEXT NOT NULL CHECK (role IN ('teacher', 'driver', 'peon', 'accountant', 'principal', 'librarian', 'security')),
    employee_code TEXT UNIQUE,
    department TEXT,
    joining_date TEXT,
    salary REAL DEFAULT 0.0,
    status TEXT DEFAULT 'active',
    subject_specialization TEXT,
    vehicle_assigned TEXT,
    can_login BOOLEAN DEFAULT false,
    user_id INTEGER NULL REFERENCES users(id),
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    class_id TEXT NOT NULL,
    stream TEXT,
    total_fee REAL NOT NULL DEFAULT 0.0,
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attendance (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id),
    class_id TEXT NOT NULL,
    date TEXT NOT NULL,            -- e.g., '2023-10-27'
    period INTEGER NOT NULL,       -- 1 to 8
    status TEXT NOT NULL CHECK (status IN ('Present', 'Absent', 'Half-Day')),
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(student_id, date, period)
);

CREATE TABLE IF NOT EXISTS marks (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id),
    date TEXT NOT NULL,
    exam_type TEXT NOT NULL,       -- 'Midterm', 'Final'
    subject TEXT NOT NULL,
    marks_obtained REAL NOT NULL,
    total_marks REAL NOT NULL,
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS fees (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id),
    amount_paid REAL NOT NULL,
    payment_date TEXT NOT NULL,
    payment_mode TEXT NOT NULL,
    receipt_number TEXT UNIQUE NOT NULL,
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staff_assignments (
    id TEXT PRIMARY KEY,
    staff_id TEXT NOT NULL REFERENCES staff(id),
    class_id TEXT NOT NULL,
    subject TEXT NOT NULL,
    academic_year TEXT NOT NULL DEFAULT '2026-27',
    max_periods_per_day INTEGER DEFAULT 6,
    max_periods_per_week INTEGER DEFAULT 30,
    is_class_teacher BOOLEAN DEFAULT false,
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_logs (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    resolution_strategy TEXT NOT NULL,
    local_data JSONB,
    server_data JSONB,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT
);
