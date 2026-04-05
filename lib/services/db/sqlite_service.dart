import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';

class SQLiteService {
  static Database? _database;

  // ── Singleton Access ─────────────────────────────────────────────────

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // ── Initialize Database ──────────────────────────────────────────────

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Table Creation ───────────────────────────────────────────────────

  Future<void> _createTables(Database db, int version) async {
    // ── Master Tables ──────────────────────────────────────────────────

    await db.execute('''
      CREATE TABLE classes (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        section TEXT NOT NULL,
        stream TEXT,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(class_name, section, stream)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_classes_name_section ON classes(class_name, section)');

    await db.execute('''
      CREATE TABLE periods (
        id TEXT PRIMARY KEY,
        period_number INTEGER NOT NULL UNIQUE,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db
        .execute('CREATE INDEX idx_periods_number ON periods(period_number)');

    // ── Entity Tables ──────────────────────────────────────────────────

    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_image_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        roll_number TEXT NOT NULL,
        class_id TEXT NOT NULL,
        email TEXT,
        phone TEXT NOT NULL,
        parent_name TEXT NOT NULL,
        parent_phone TEXT NOT NULL,
        parent_occupation TEXT,
        mother_name TEXT,
        mother_phone TEXT,
        profile_image_url TEXT,
        date_of_birth TEXT NOT NULL,
        gender TEXT NOT NULL,
        caste TEXT,
        category TEXT,
        religion TEXT,
        nationality TEXT,
        blood_group TEXT,
        address TEXT NOT NULL,
        city TEXT,
        state TEXT,
        pincode TEXT,
        previous_school TEXT,
        previous_class TEXT,
        aadhar_number TEXT,
        admission_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'approved',
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (class_id) REFERENCES classes(id)
      )
    ''');
    await db
        .execute('CREATE INDEX idx_students_class_id ON students(class_id)');

    // Implemented UNIQUE attendance constraint to fix write protection bug!
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        date TEXT NOT NULL,
        period_number INTEGER,
        status TEXT NOT NULL,
        remarks TEXT,
        marked_by TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(student_id, date, period_number),
        FOREIGN KEY (student_id) REFERENCES students(id),
        FOREIGN KEY (class_id) REFERENCES classes(id),
        FOREIGN KEY (period_number) REFERENCES periods(period_number)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_attendance_student_date ON attendance(student_id, date)');
    await db.execute(
        'CREATE INDEX idx_attendance_class_date ON attendance(class_id, date)');
    await db.execute(
        'CREATE INDEX idx_attendance_period ON attendance(period_number)');

    await db.execute('''
      CREATE TABLE timetable (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        day TEXT NOT NULL,
        subject TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        teacher_name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        period_number INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (class_id) REFERENCES classes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE marks (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        exam_type TEXT NOT NULL,
        marks_obtained REAL NOT NULL,
        total_marks REAL NOT NULL,
        grade TEXT,
        remarks TEXT,
        exam_date TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(student_id, subject, exam_type),
        FOREIGN KEY (student_id) REFERENCES students(id),
        FOREIGN KEY (class_id) REFERENCES classes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE student_fees (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        month INTEGER NOT NULL,
        amount_due REAL NOT NULL DEFAULT 0.0,
        amount_paid REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'UNPAID',
        paid_date TEXT,
        device_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notices (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        posted_by TEXT NOT NULL,
        target_audience TEXT NOT NULL,
        posted_at TEXT NOT NULL,
        expires_at TEXT,
        is_important INTEGER NOT NULL DEFAULT 0,
        attachment_url TEXT,
        updated_at TEXT NOT NULL,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Sync Resolution Tables
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        server_data TEXT NOT NULL,
        local_data TEXT NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0,
        resolution_strategy TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        role TEXT NOT NULL,
        employee_code TEXT UNIQUE,
        department TEXT,
        joining_date TEXT,
        salary REAL DEFAULT 0.0,
        status TEXT DEFAULT 'active',
        subject_specialization TEXT,
        vehicle_assigned TEXT,
        can_login INTEGER DEFAULT 0,
        user_id INTEGER,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE staff_assignments (
        id TEXT PRIMARY KEY,
        staff_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        academic_year TEXT NOT NULL DEFAULT '2026-27',
        max_periods_per_day INTEGER DEFAULT 6,
        max_periods_per_week INTEGER DEFAULT 30,
        is_class_teacher INTEGER DEFAULT 0,
        device_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new student columns
      final newCols = [
        'parent_occupation TEXT',
        'mother_name TEXT',
        'mother_phone TEXT',
        'caste TEXT',
        'category TEXT',
        'religion TEXT',
        'nationality TEXT',
        'blood_group TEXT',
        'city TEXT',
        'state TEXT',
        'pincode TEXT',
        'previous_school TEXT',
        'previous_class TEXT',
        'aadhar_number TEXT',
        'status TEXT DEFAULT \'approved\'',
      ];
      for (final col in newCols) {
        try {
          await db.execute('ALTER TABLE students ADD COLUMN $col');
        } catch (_) {} // Column may already exist
      }
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          role TEXT NOT NULL,
          employee_code TEXT UNIQUE,
          department TEXT,
          joining_date TEXT,
          salary REAL DEFAULT 0.0,
          status TEXT DEFAULT 'active',
          subject_specialization TEXT,
          vehicle_assigned TEXT,
          can_login INTEGER DEFAULT 0,
          user_id INTEGER,
          device_id TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_assignments (
          id TEXT PRIMARY KEY,
          staff_id TEXT NOT NULL,
          class_id TEXT NOT NULL,
          subject TEXT NOT NULL,
          academic_year TEXT NOT NULL DEFAULT '2026-27',
          max_periods_per_day INTEGER DEFAULT 6,
          max_periods_per_week INTEGER DEFAULT 30,
          is_class_teacher INTEGER DEFAULT 0,
          device_id TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      // Migrate structure safely
      await db.execute('DROP TABLE IF EXISTS fees');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_fees (
          id TEXT PRIMARY KEY,
          student_id TEXT NOT NULL,
          academic_year TEXT NOT NULL,
          month INTEGER NOT NULL,
          amount_due REAL NOT NULL DEFAULT 0.0,
          amount_paid REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'UNPAID',
          paid_date TEXT,
          device_id TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (student_id) REFERENCES students(id)
        )
      ''');
    }
  }

  // ── Generic CRUD Helpers ─────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> deleteRecord(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    // We enforce soft-deletes conceptually now by updating 'is_deleted'
    // but leaving real SQL delete for true cleanup routines
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> transaction(
      Future<void> Function(Transaction txn) action) async {
    final db = await database;
    await db.transaction(action);
  }

  Future<Map<String, dynamic>> getStudentSummary(String studentId) async {
    final db = await database;

    // 1. Attendance
    final attRaw = await db.rawQuery('''
      SELECT COUNT(*) as total, SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) as present 
      FROM attendance 
      WHERE student_id = ? AND is_deleted = 0
    ''', [studentId]);

    final attTotal =
        int.tryParse(attRaw.first['total']?.toString() ?? '0') ?? 0;
    final attPresent =
        int.tryParse(attRaw.first['present']?.toString() ?? '0') ?? 0;
    final attPct = attTotal > 0
        ? ((attPresent / attTotal) * 100).toStringAsFixed(1)
        : '0.0';

    // 2. Fees
    final feeRaw = await db.rawQuery('''
      SELECT SUM(amount_due) as total_due, SUM(amount_paid) as total_paid
      FROM student_fees
      WHERE student_id = ? AND is_deleted = 0
    ''', [studentId]);

    final totalDue =
        double.tryParse(feeRaw.first['total_due']?.toString() ?? '0') ?? 0;
    final totalPaid =
        double.tryParse(feeRaw.first['total_paid']?.toString() ?? '0') ?? 0;

    // 3. Marks
    final marksRaw = await db.rawQuery('''
      SELECT subject, marks_obtained, total_marks, exam_type
      FROM marks 
      WHERE student_id = ? AND is_deleted = 0
      ORDER BY exam_date DESC LIMIT 10
    ''', [studentId]);

    // 4. Alerts/Notices
    final alertsRaw = await db.rawQuery('''
      SELECT id, title as message, is_important as is_read, posted_at as created_at
      FROM notices
      WHERE is_deleted = 0
      ORDER BY posted_at DESC LIMIT 5
    ''');

    return {
      'attendance': {
        'total': attTotal,
        'present': attPresent,
        'percentage': attPct
      },
      'fees': {'total_due': totalDue, 'total_paid': totalPaid},
      'marks': marksRaw,
      'alerts': alertsRaw,
    };
  }

  Future<List<Map<String, dynamic>>> getStudentFeeTransactions(
      String studentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT fee_type as month, paid_amount as amount_paid, paid_date, status, transaction_id as payment_method
      FROM fees
      WHERE student_id = ? AND is_deleted = 0
      ORDER BY due_date DESC LIMIT 20
    ''', [studentId]);
  }

  Future<Map<String, dynamic>> getFeeAnalytics() async {
    final db = await database;

    try {
      final summary = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(amount_due), 0) as expected,
          COALESCE(SUM(amount_paid), 0) as collected,
          COALESCE(SUM(amount_due - amount_paid), 0) as pending
        FROM student_fees
        WHERE is_deleted = 0
      ''');

      final paidCountRaw = await db.rawQuery('''
        SELECT COUNT(DISTINCT student_id) as count
        FROM student_fees 
        WHERE is_deleted = 0 AND (status = 'PAID' OR (amount_due - amount_paid) <= 0)
      ''');

      final dueCountRaw = await db.rawQuery('''
        SELECT COUNT(DISTINCT student_id) as count
        FROM student_fees 
        WHERE is_deleted = 0 AND status != 'PAID' AND (amount_due - amount_paid) > 0
      ''');

      final expected = summary.isNotEmpty ? summary.first['expected'] : 0;
      final collected = summary.isNotEmpty ? summary.first['collected'] : 0;
      final pending = summary.isNotEmpty ? summary.first['pending'] : 0;
      final paidStudents =
          paidCountRaw.isNotEmpty ? paidCountRaw.first['count'] : 0;
      final dueStudents =
          dueCountRaw.isNotEmpty ? dueCountRaw.first['count'] : 0;

      final transactions = await db.rawQuery('''
        SELECT sf.id, sf.amount_paid, sf.amount_due, sf.paid_date, sf.status, sf.month, 'N/A' as payment_method, 
               COALESCE(s.name, 'Unknown') as student_name
        FROM student_fees sf
        LEFT JOIN students s ON s.id = sf.student_id
        WHERE sf.is_deleted = 0 AND sf.amount_paid > 0
        ORDER BY sf.paid_date DESC
        LIMIT 10
      ''');

      final dueStudentsList = await db.rawQuery('''
        SELECT sf.id, sf.amount_due as total_due, sf.created_at, sf.student_id, 
               COALESCE(s.name, 'Unknown') as student_name, s.class_id, s.phone
        FROM student_fees sf
        LEFT JOIN students s ON s.id = sf.student_id
        WHERE sf.is_deleted = 0 AND sf.amount_due > 0 AND sf.status != 'PAID'
        ORDER BY sf.created_at ASC
      ''');

      return {
        "expected": expected,
        "collected": collected,
        "pending": pending,
        "paid_students": paidStudents,
        "due_students": dueStudents,
        "transactions": transactions,
        "due_students_list": dueStudentsList,
      };
    } catch (e) {
      print("SQLITE FEE ANALYTICS ERROR: \$e");
      return {
        "expected": 0,
        "collected": 0,
        "pending": 0,
        "paid_students": 0,
        "due_students": 0,
        "transactions": [],
        "due_students_list": []
      };
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
