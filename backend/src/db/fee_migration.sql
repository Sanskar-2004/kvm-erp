-- KVM ERP Phase 5: Fee Structure + Student Fees + Alerts

CREATE TABLE IF NOT EXISTS fee_structure (
    id TEXT PRIMARY KEY,
    class_id TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    monthly_fee_amount REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT
);

CREATE TABLE IF NOT EXISTS student_fees (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id),
    academic_year TEXT NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    amount_due REAL NOT NULL DEFAULT 0.0,
    amount_paid REAL NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'UNPAID' CHECK (status IN ('PAID', 'UNPAID', 'PARTIAL')),
    paid_date TEXT,
    device_id TEXT,
    is_synced BOOLEAN DEFAULT TRUE,
    is_deleted INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT,
    UNIQUE(student_id, academic_year, month)
);

CREATE TABLE IF NOT EXISTS alerts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP::TEXT
);

-- Update users role constraint to support all 5 roles
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'teacher', 'student', 'parent', 'accountant'));
