# KVM ERP — Complete Study Guide & Technical Documentation

> **A detailed, word-by-word guide to understanding the entire KVM ERP School Management System.**
> Prepared for academic presentation and professor review.

---

# TABLE OF CONTENTS

1. [What is KVM ERP?](#1-what-is-kvm-erp)
2. [Technology Stack Explained](#2-technology-stack-explained)
3. [Architecture & How Everything Connects](#3-architecture--how-everything-connects)
4. [Project Folder Structure Explained](#4-project-folder-structure-explained)
5. [Flutter Frontend — Deep Dive](#5-flutter-frontend--deep-dive)
6. [Node.js Backend — Deep Dive](#6-nodejs-backend--deep-dive)
7. [Database Design — PostgreSQL & SQLite](#7-database-design--postgresql--sqlite)
8. [Authentication System](#8-authentication-system)
9. [Sync Engine — Offline-First Architecture](#9-sync-engine--offline-first-architecture)
10. [Feature Modules Explained](#10-feature-modules-explained)
11. [State Management with Riverpod](#11-state-management-with-riverpod)
12. [Deployment & DevOps](#12-deployment--devops)
13. [Security Practices](#13-security-practices)
14. [Glossary of Terms](#14-glossary-of-terms)

---

# 1. What is KVM ERP?

## 1.1 The Problem
Schools manage thousands of students, teachers, and financial records manually using paper registers or basic Excel sheets. This leads to:
- Data loss when registers are damaged
- No real-time access to student information
- Parents have no visibility into their child's progress
- Fees tracking is inaccurate and unorganized
- Attendance is slow and error-prone

## 1.2 The Solution
KVM ERP is a **full-stack, offline-first, multi-role School Enterprise Resource Planning (ERP) system**. It is:
- A **mobile app** (built with Flutter) that works on Android phones
- A **cloud backend** (built with Node.js) that stores all data securely
- An **offline-first system** that works even without internet, then syncs when online
- A **multi-role system** with 5 different user types: Admin, Teacher, Accountant, Parent, and Student

## 1.3 What "ERP" Means
ERP stands for **Enterprise Resource Planning**. In a school context, "enterprise" means the school itself. "Resource Planning" means managing all the school's resources:
- **Human Resources**: Students, Teachers, Staff
- **Financial Resources**: Fees, Payments, Dues
- **Academic Resources**: Attendance, Marks, Timetables
- **Communication**: Notices, Alerts

## 1.4 What "Offline-First" Means
Most apps need internet to work. KVM ERP is different:
1. All data is stored **locally on the phone** in a SQLite database
2. The user can add students, mark attendance, etc. **without internet**
3. When internet becomes available, the app **automatically syncs** with the cloud
4. This is critical for schools in rural India where internet is unreliable

---

# 2. Technology Stack Explained

## 2.1 Frontend — Flutter (Dart)

### What is Flutter?
Flutter is Google's **UI toolkit** for building apps from a single codebase. Instead of writing separate code for Android (Java/Kotlin) and iOS (Swift), you write ONE codebase in Dart and Flutter compiles it to both platforms.

### What is Dart?
Dart is the programming language used by Flutter. It is:
- **Object-oriented**: Everything is a class/object
- **Strongly typed**: Variables have explicit types (`String name`, `int age`)
- **Async-friendly**: Uses `async/await` for network calls and database operations

### Why Flutter for this project?
- **Cross-platform**: Works on Android, iOS, Windows, Web from ONE codebase
- **Hot reload**: During development, changes appear instantly without restarting the app
- **Material Design**: Built-in beautiful UI components
- **Large ecosystem**: Thousands of packages available

### Key Flutter Packages Used

| Package | Version | What It Does |
|---|---|---|
| `flutter_riverpod` | ^2.4.9 | State management — manages app data flow |
| `sqflite` | ^2.3.2 | SQLite database for Android/iOS |
| `sqflite_common_ffi` | ^2.4.0 | SQLite for Windows/Linux/Mac desktop |
| `http` | ^1.2.0 | Makes HTTP requests to the backend API |
| `shared_preferences` | ^2.2.2 | Stores small data (login token, user role) locally |
| `google_fonts` | ^8.0.2 | Loads the Inter font from Google |
| `intl` | ^0.19.0 | Date/number formatting (₹1,000 format) |
| `uuid` | ^4.3.3 | Generates unique IDs for records |
| `path_provider` | ^2.1.2 | Finds the correct folder path to store database files |

---

## 2.2 Backend — Node.js (JavaScript)

### What is Node.js?
Node.js is a **JavaScript runtime** that lets you run JavaScript on a server (not just in a browser). It handles:
- Receiving API requests from the Flutter app
- Processing data (login, sync, fee calculations)
- Communicating with the PostgreSQL database

### What is Express.js?
Express is a **web framework** for Node.js. It simplifies creating API endpoints. Without Express, you'd write hundreds of lines of HTTP handling code. With Express, it's just:
```javascript
app.post('/api/auth/login', authController.login);
```

### Backend Packages Used

| Package | What It Does |
|---|---|
| `express` ^4.19.2 | Web framework — handles HTTP routes and requests |
| `pg` ^8.11.5 | PostgreSQL client — connects Node.js to the database |
| `bcrypt` ^5.1.1 | Password hashing — securely stores passwords |
| `jsonwebtoken` ^9.0.2 | JWT — creates and verifies authentication tokens |
| `cors` ^2.8.5 | Cross-Origin Resource Sharing — allows Flutter to talk to the server |
| `dotenv` ^16.4.5 | Loads environment variables from `.env` file |

---

## 2.3 Database — PostgreSQL (Cloud) + SQLite (Local)

### PostgreSQL (Cloud Database)
- **What**: A powerful, open-source relational database
- **Where it runs**: On **Neon.tech** (a cloud PostgreSQL hosting service)
- **Why PostgreSQL**: It supports complex queries, JSON storage, and handles thousands of concurrent connections
- **What Neon.tech is**: A serverless PostgreSQL platform — you don't need to manage servers, Neon handles scaling, backups, and uptime

### SQLite (Local Database)
- **What**: A lightweight database that runs **directly on the phone**
- **Why**: Enables offline functionality — data is stored locally first
- **No server needed**: SQLite is embedded inside the app itself
- **Version**: The project uses SQLite schema version 2 (with migration support for upgrading from version 1)

### Why TWO Databases?
This is the **offline-first** architecture:
```
Phone (SQLite) ←→ Sync Engine ←→ Cloud (PostgreSQL on Neon.tech)
```
1. User adds a student → saved to SQLite immediately
2. Sync engine detects new data → pushes to PostgreSQL
3. Another device opens the app → pulls from PostgreSQL → saves to local SQLite

---

## 2.4 Cloud Hosting — Render.com

### What is Render?
Render is a **cloud hosting platform** (like Heroku, Vercel, or AWS but simpler). It:
- Hosts the Node.js backend server
- Auto-deploys when you push code to GitHub
- Provides a public URL: `https://kvm-erp.onrender.com`

### How Deployment Works
```
Developer pushes code to GitHub
    ↓
Render detects the push (webhook)
    ↓
Render pulls the latest code
    ↓
Render runs `npm install` → `npm start`
    ↓
Server is live at kvm-erp.onrender.com
```

---

## 2.5 Version Control — Git & GitHub

### What is Git?
Git is a **version control system**. It tracks every change made to every file. If something breaks, you can go back to a working version.

### What is GitHub?
GitHub is a **cloud platform for Git repositories**. The project code lives at:
```
https://github.com/Sanskar-2004/kvm-erp
```

---

# 3. Architecture & How Everything Connects

## 3.1 High-Level Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Phone)                       │
│                                                              │
│  ┌─────────┐    ┌──────────┐    ┌──────────┐                │
│  │ Login    │    │ Dashboard│    │ Students │                │
│  │ Screen   │    │ Screen   │    │ Screen   │  ...more       │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘                │
│       │               │               │                      │
│       └───────────────┼───────────────┘                      │
│                       │                                      │
│              ┌────────▼────────┐                             │
│              │   RIVERPOD      │   ← State Management        │
│              │   Providers     │                             │
│              └────────┬────────┘                             │
│                       │                                      │
│         ┌─────────────┼─────────────┐                        │
│         │             │             │                        │
│  ┌──────▼──────┐  ┌───▼───┐  ┌─────▼─────┐                  │
│  │ Repositories│  │  HTTP  │  │ SQLite DB │  ← Local Storage │
│  │ (Data Logic)│  │ Client │  │ (Offline) │                  │
│  └─────────────┘  └───┬───┘  └───────────┘                  │
│                       │                                      │
└───────────────────────┼──────────────────────────────────────┘
                        │ HTTPS (Internet)
                        │
┌───────────────────────▼──────────────────────────────────────┐
│                   RENDER.COM (Cloud)                          │
│                                                              │
│  ┌─────────────────────────────────────────────┐             │
│  │            NODE.JS + EXPRESS                 │             │
│  │                                             │             │
│  │  /api/auth     → Authentication             │             │
│  │  /api/sync     → Push/Pull data sync        │             │
│  │  /api/students → Student management         │             │
│  │  /api/fees     → Fee management             │             │
│  │  /api/timetable→ Timetable with clash check │             │
│  │  /api/admin    → Admin-specific reports     │             │
│  │  /api/parent   → Parent-specific data       │             │
│  │  /api/staff    → Staff management           │             │
│  └──────────┬──────────────────────────────────┘             │
│             │                                                │
│  ┌──────────▼──────────┐                                     │
│  │   JWT Middleware     │  ← Verifies token on every request │
│  └──────────┬──────────┘                                     │
│             │                                                │
└─────────────┼────────────────────────────────────────────────┘
              │ SSL Connection
              │
┌─────────────▼────────────────────────────────────────────────┐
│              NEON.TECH (Cloud Database)                       │
│                                                              │
│  ┌─────────────────────────────────────────────┐             │
│  │          PostgreSQL Database                 │             │
│  │                                             │             │
│  │  12 Tables: users, students, attendance,    │             │
│  │  marks, fees, timetable, notices, classes,  │             │
│  │  staff, subjects, alerts, parent_student_map│             │
│  └─────────────────────────────────────────────┘             │
└──────────────────────────────────────────────────────────────┘
```

## 3.2 How a Login Request Flows

```
1. User types "admin" and "admin" on the Flutter login screen
2. Flutter sends HTTP POST to https://kvm-erp.onrender.com/api/auth/login
   Body: { "email": "admin", "password": "admin" }
3. Express.js receives the request at authRoutes → authController.login()
4. Controller checks: no '@' in "admin", so appends "@kvm.edu" → "admin@kvm.edu"
5. Queries PostgreSQL: SELECT * FROM users WHERE email = 'admin@kvm.edu'
6. Finds the user record with password_hash
7. bcrypt.compare("admin", stored_hash) → returns true (password matches)
8. Creates a JWT token with { userId: 1, role: "admin" }, signed with JWT_SECRET
9. Sends back: { status: "success", token: "eyJhbG...", role: "admin", userId: 1 }
10. Flutter receives the response
11. Saves token + role + userId to SharedPreferences (local persistent storage)
12. Sets the global userRoleProvider to UserRole.admin
13. Navigates to MainLayout → shows AdminDashboard
```

---

# 4. Project Folder Structure Explained

## 4.1 Root Directory

```
KVM/
├── android/                    # Android-specific configuration + manifest
├── ios/                       # iOS-specific configuration (not used currently)
├── windows/                   # Windows desktop configuration
├── lib/                       # ★ ALL FLUTTER/DART CODE LIVES HERE
├── backend/                   # ★ ALL NODE.JS SERVER CODE LIVES HERE
├── build/                     # Generated build output (APK lives here)
├── pubspec.yaml               # Flutter dependencies (like package.json for Flutter)
├── pubspec.lock               # Locked dependency versions
├── README.md                  # Project documentation
└── KVM_ERP_STUDY_GUIDE.md     # This file
```

## 4.2 Flutter Code — `lib/` Directory (Every File Explained)

```
lib/
├── main.dart                       ★ ENTRY POINT — App starts here
├── app_router.dart                 Route definitions for navigation
│
├── core/                           Shared utilities used across the app
│   ├── constants/
│   │   ├── app_constants.dart      Database name ("kvm_erp.db"), version (2), API URL
│   │   ├── app_colors.dart         Color palette definitions (hex codes)
│   │   └── app_text_styles.dart    Font sizes, weights, text themes
│   │
│   ├── exceptions/                 Custom error classes
│   │
│   ├── theme/
│   │   └── app_theme.dart          Material3 theme: colors, card styles, AppBar style
│   │
│   ├── utils/
│   │   ├── academic_utils.dart     Grade calculation (A+, A, B+...), percentage logic
│   │   ├── device_identity.dart    Generates a unique device ID for sync tracking
│   │   ├── helpers.dart            Date formatting, number formatting (₹1,000)
│   │   ├── network_service.dart    Checks if internet is available, triggers sync
│   │   └── validator_service.dart  Validates student names, roll numbers, marks
│   │
│   └── widgets/
│       ├── main_layout.dart        ★ THE SHELL — AppBar + role badge + bottom nav + logout
│       └── sync_status_badge.dart  Animated pill showing sync state (✓ synced, ↑ pending...)
│
├── models/                         Data classes (blueprints for each entity)
│   ├── student_model.dart          30+ fields: name, class, gender, caste, parent info...
│   ├── user_model.dart             User: id, name, email, role, phone
│   ├── attendance_model.dart       Attendance: student_id, date, status (Present/Absent)
│   ├── marks_model.dart            Marks: student_id, subject, exam_type, marks
│   ├── fee_model.dart              Fee: student_id, amount, paid_amount, status
│   ├── timetable_model.dart        Timetable: class_id, day, subject, teacher, period
│   ├── class_model.dart            Class: id, class_name, section, stream
│   ├── notice_model.dart           Notice: title, description, target_audience
│   ├── period_model.dart           Period: period_number, start_time, end_time
│   ├── staff_model.dart            Staff: name, phone, staff_type, qualifications
│   └── staff_assignment_model.dart Staff assignment: teacher → class → subject mapping
│
├── features/                       ★ MAIN FEATURE MODULES (organized by domain)
│   ├── auth/                       Authentication (login/logout)
│   ├── dashboard/                  All 5 role dashboards
│   ├── students/                   Student CRUD + detail view
│   ├── attendance/                 Attendance marking
│   ├── marks/                      Marks entry + ranking
│   ├── fees/                       Fee management
│   ├── timetable/                  Timetable viewing + management
│   ├── admission/                  Student admission workflow
│   ├── notices/                    School notices/announcements
│   ├── sync/                       Sync conflict logs viewer
│   ├── backup/                     Data backup functionality
│   ├── staff/                      Staff management
│   ├── academics/                  Academic utilities
│   └── ai/                         AI-powered features
│
└── services/                       Backend communication + data services
    ├── api/                        API client helpers
    ├── backup/                     Backup service logic
    ├── db/
    │   └── sqlite_service.dart     ★ SQLITE DATABASE — table creation, CRUD, migrations
    └── sync/
        └── sync_service.dart       ★ SYNC ENGINE — push local changes, pull server changes
```

## 4.3 Backend Code — `backend/` Directory (Every File Explained)

```
backend/
├── .env                            ★ SECRET KEYS (DATABASE_URL, JWT_SECRET) — NEVER commit this
├── .gitignore                      Tells git to ignore node_modules/ and .env
├── package.json                    Dependencies + start scripts
├── package-lock.json               Locked versions of all npm packages
│
├── src/
│   ├── server.js                   ★ ENTRY POINT — Express app setup, 9 route mounts
│   │
│   ├── config/
│   │   └── db.js                   PostgreSQL connection pool using DATABASE_URL
│   │
│   ├── middleware/
│   │   └── authMiddleware.js       JWT verification — runs before every protected route
│   │
│   ├── controllers/                Business logic for each feature
│   │   ├── authController.js       register, login, resetPasswords
│   │   ├── syncController.js       syncPush (UPSERT), syncPull (delta query)
│   │   ├── studentController.js    getPendingStudents, approveStudent
│   │   ├── feeController.js        getFees, updateFee, generateFee, alerts
│   │   ├── timetableController.js  createSlot (with 409 clash detection)
│   │   ├── adminController.js      financeSummary, classRanks, dueFees
│   │   └── parentController.js     getChildren, linkChild, studentSummary
│   │
│   ├── routes/                     URL → Controller mapping
│   │   ├── authRoutes.js           /api/auth/* (public)
│   │   ├── syncRoutes.js           /api/sync/* (JWT protected)
│   │   ├── studentRoutes.js        /api/students/*
│   │   ├── feeRoutes.js            /api/fees/*
│   │   ├── timetableRoutes.js      /api/timetable/*
│   │   ├── adminRoutes.js          /api/admin/*
│   │   ├── parentRoutes.js         /api/parent/*
│   │   ├── staffRoutes.js          /api/staff/*
│   │   └── assignmentRoutes.js     /api/assignments/*
│   │
│   └── db/                         SQL migration files
│       ├── init.sql                Initial schema creation (12 tables)
│       ├── fee_migration.sql       Fee structure + student_fees tables
│       └── phase2_migration.sql    Parent-student map, subjects, alerts
│
├── seed-users.js                   Seeds 5 default user accounts
├── wipe_db.js                      Dangerous! Drops all tables (development only)
├── testdb.js                       Tests database connection
└── health_probe.js                 Server health check script
```

---

# 5. Flutter Frontend — Deep Dive

## 5.1 main.dart — The Entry Point

This is the first file that runs when the app starts. Here's exactly what it does, line by line:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Required before any async work
```
**Why `ensureInitialized()`?** Flutter's engine (which draws pixels on screen) must be fully started before we can access things like SharedPreferences or databases. This line guarantees that.

```dart
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || ...)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
```
**Why FFI?** `sqflite` (the SQLite package) uses native Android/iOS database APIs. But on Windows/Linux/Mac, those APIs don't exist. `sqflite_common_ffi` uses **FFI (Foreign Function Interface)** to directly call the C library of SQLite. Without this, you get "database factory not initialized" on desktop.

```dart
  final authRepo = AuthRepository();
  var session = await authRepo.getSession(); // Check SharedPreferences for saved login
```
**Session persistence**: When you login, the app saves your JWT token to SharedPreferences. On next app launch, it reads this back. If a valid token exists, you skip the login screen.

```dart
  if (session != null && !session.token.contains('.')) {
    await authRepo.clearSession();
    session = null;
  }
```
**Stale token detection**: Real JWT tokens have THREE parts separated by dots: `header.payload.signature`. If the stored token doesn't have a dot, it's fake/stale/hardcoded and must be cleared.

```dart
  runApp(ProviderScope(child: KVMErpApp(initialSession: session)));
```
**`ProviderScope`** is Riverpod's container. Every `Provider` in the app lives inside this scope. Without it, `ref.read()` and `ref.watch()` would crash.

## 5.2 MainLayout — The App Shell

After login, every screen lives inside `MainLayout`. This widget:

1. **Reads the user's role** from `userRoleProvider`
2. **Selects screens and navigation items** based on the role:
   - Admin: Dashboard, Students, Attendance, Fees, Audit (5 tabs)
   - Teacher: Dashboard, Students (2 tabs)
   - Accountant: Dashboard, Fees (2 tabs)
   - Parent: Home, Fees (2 tabs)
   - Student: Home, Fees (2 tabs)
3. **Shows the AppBar** with:
   - App title "KVM ERP"
   - Color-coded role badge (Admin=Red, Teacher=Blue, etc.)
   - SyncStatusBadge (shows sync state)
   - Profile popup menu with Logout
4. **Shows BottomNavigationBar** for switching between tabs

## 5.3 Material3 Theme

The app uses Google's Material Design 3 (Material You):
```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF4A6CF7)),  // Blue-purple seed
  useMaterial3: true,
  textTheme: GoogleFonts.interTextTheme(),  // Inter font from Google Fonts
)
```
**`fromSeed`** generates an entire color palette (primary, secondary, tertiary, surface, background, error) from a single seed color. This ensures all colors are harmonious.

## 5.4 Auto-Sync System

```dart
// Every 30 minutes, trigger sync
_syncTimer = Timer.periodic(const Duration(minutes: 30), (_) => _triggerSync());

// Also sync immediately when any local write happens
_syncTriggerSub = SQLiteService.onSyncQueued.stream.listen((_) => _triggerSync());
```
The app syncs in TWO ways:
1. **Periodic**: Every 30 minutes (battery-friendly background sync)
2. **Event-driven**: Whenever a repository adds something to `sync_queue`, it fires immediately

---

# 6. Node.js Backend — Deep Dive

## 6.1 server.js — How the Backend Starts

```javascript
require('dotenv').config();           // Load .env file (DATABASE_URL, JWT_SECRET)
const express = require('express');
const cors = require('cors');
const app = express();
app.use(cors());                     // Allow Flutter app to call this server
app.use(express.json({ limit: '50mb' }));  // Parse JSON bodies, allow up to 50MB for sync
```

**CORS (Cross-Origin Resource Sharing)**: Browsers and some HTTP clients block requests to different domains by default. `cors()` tells the server "accept requests from ANY origin" — necessary because the Flutter app and the server are on different domains.

**Body limit 50MB**: Sync pushes can contain thousands of records. The default Express limit is 100KB which would reject large syncs.

## 6.2 Route Mounting

```javascript
app.use('/api/auth', authRoutes);         // Public routes (no JWT needed)
app.use('/api/sync', syncRoutes);         // Protected (JWT required)
app.use('/api/students', studentRoutes);  // Protected
// ... 6 more route groups
```

When Flutter calls `POST https://kvm-erp.onrender.com/api/auth/login`, Express matches `/api/auth` → `authRoutes` → finds `POST /login` → calls `authController.login()`.

## 6.3 Database Configuration (db.js)

```javascript
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,  // Neon.tech connection string
  ssl: { rejectUnauthorized: false }           // Required for Neon.tech SSL
});
```

**Connection Pool**: Instead of opening/closing database connections for each request (slow), a Pool keeps several connections open and reuses them. This is critical for performance.

**SSL**: Neon.tech requires encrypted connections. `rejectUnauthorized: false` allows self-signed SSL certificates.

## 6.4 Auth Controller — How Login Works

```javascript
exports.login = async (req, res) => {
    const { email, password } = req.body;
    const lookupEmail = email.includes('@') ? email : `${email}@kvm.edu`;
```
**Username shortcut**: The user types just "admin" instead of "admin@kvm.edu". The server detects there's no `@` and automatically appends `@kvm.edu`.

```javascript
    const user = result.rows[0];
    const isValid = await bcrypt.compare(password, user.password_hash);
```
**bcrypt.compare**: The database stores a HASH of the password (like `$2b$10$abc123...`), not the actual password. `bcrypt.compare` takes the plain text password, hashes it the same way, and checks if it matches the stored hash. This is why even if the database is hacked, passwords are safe.

```javascript
    const payload = { userId: effectiveUserId, role: user.role, databaseId: user.id };
    const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });
```
**JWT Creation**: The server creates a JSON Web Token containing the user's ID and role, signed with a secret key. This token:
- Is valid for 7 days
- Cannot be faked (because only the server knows JWT_SECRET)
- Is sent with every subsequent API request as proof of identity

## 6.5 JWT Middleware — How Protected Routes Work

```javascript
const authMiddleware = (req, res, next) => {
    const authHeader = req.headers.authorization;  // "Bearer eyJhbG..."
    const token = authHeader.split(' ')[1];        // Extract just the token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);  // Verify signature
    req.user = decoded;  // Attach user info to request
    next();              // Allow the request to proceed
};
```
Every protected route (sync, students, fees, etc.) passes through this middleware FIRST. If the token is missing, expired, or tampered with, the request is rejected with 401 Unauthorized.

## 6.6 Sync Controller — The Heart of Offline-First

### syncPush — Phone → Cloud

```javascript
const ALLOWED_TABLES = ['users', 'students', 'attendance', 'marks', 'fees', ...];
```
**Security**: Only whitelisted table names are accepted. If someone sends `{ "DROP TABLE users": [...] }`, it's silently ignored.

```javascript
// For each record, build an UPSERT query:
INSERT INTO "students" ("id", "name", "class_id", ...)
VALUES ($1, $2, $3, ...)
ON CONFLICT (id) DO UPDATE SET "name" = EXCLUDED."name", ...
WHERE "students".updated_at < EXCLUDED.updated_at
```
**UPSERT**: This is INSERT + UPDATE combined:
- If the `id` doesn't exist → INSERT new row
- If the `id` already exists → UPDATE only if the incoming `updated_at` is newer
- This prevents older data from overwriting newer data (conflict resolution)

### syncPull — Cloud → Phone

```javascript
SELECT * FROM "students" WHERE updated_at > '2024-01-01T00:00:00Z'
```
**Delta sync**: Instead of downloading ALL data every time, it only downloads records that changed since the last sync. This saves bandwidth and is much faster.

---

# 7. Database Design — PostgreSQL & SQLite

## 7.1 Complete Table Reference

### users
| Column | Type | Description |
|---|---|---|
| id | SERIAL PRIMARY KEY | Auto-incrementing unique ID |
| name | TEXT NOT NULL | Full name |
| email | TEXT UNIQUE NOT NULL | Used for login (admin@kvm.edu) |
| password_hash | TEXT NOT NULL | bcrypt hash of the password |
| role | TEXT NOT NULL | admin, teacher, parent, student, accountant |
| student_id | TEXT | Links parent/student users to their student record |
| created_at | TIMESTAMP | When the account was created |
| updated_at | TIMESTAMP | Last modification time |

### students (30+ columns — the largest table)
| Column | Type | Description |
|---|---|---|
| id | TEXT PRIMARY KEY | UUID or timestamp-based ID |
| name | TEXT NOT NULL | Student's full name |
| roll_number | TEXT NOT NULL | Class roll number |
| class_id | TEXT NOT NULL | Which class (1, 2, ... 12) |
| email | TEXT | Student's email (optional) |
| phone | TEXT NOT NULL | Student's phone |
| parent_name | TEXT NOT NULL | Father's name |
| parent_phone | TEXT NOT NULL | Father's phone |
| parent_occupation | TEXT | Father's job |
| mother_name | TEXT | Mother's name |
| mother_phone | TEXT | Mother's phone |
| date_of_birth | TEXT NOT NULL | DOB in ISO format |
| gender | TEXT NOT NULL | Male, Female, Other |
| caste | TEXT | Student's caste |
| category | TEXT | General, OBC, SC, ST, EWS |
| religion | TEXT | Hindu, Muslim, Christian, etc. |
| nationality | TEXT | Indian (default) |
| blood_group | TEXT | A+, B-, O+, etc. |
| address | TEXT NOT NULL | Full residential address |
| city | TEXT | City name |
| state | TEXT | State name |
| pincode | TEXT | PIN code |
| previous_school | TEXT | Name of previous school |
| previous_class | TEXT | Last class attended at previous school |
| aadhar_number | TEXT | 12-digit Aadhar card number |
| admission_date | TEXT NOT NULL | When admitted to this school |
| status | TEXT DEFAULT 'approved' | pending, approved, rejected |
| updated_at | TEXT NOT NULL | Last modification timestamp |
| device_id | TEXT NOT NULL | Which device created this record |
| is_synced | INTEGER DEFAULT 0 | 0 = not yet synced, 1 = synced |
| is_deleted | INTEGER DEFAULT 0 | 0 = active, 1 = soft-deleted |

### attendance
| Column | Type | Description |
|---|---|---|
| id | TEXT PRIMARY KEY | Unique attendance ID |
| student_id | TEXT FOREIGN KEY | Links to students.id |
| class_id | TEXT FOREIGN KEY | Links to classes.id |
| date | TEXT NOT NULL | Date of attendance |
| period_number | INTEGER | Which period (1-8) |
| status | TEXT NOT NULL | Present or Absent |
| marked_by | TEXT NOT NULL | Teacher who marked it |
| UNIQUE(student_id, date, period_number) | | Prevents duplicate entries |

### marks
| Column | Type | Description |
|---|---|---|
| id | TEXT PRIMARY KEY | Unique mark ID |
| student_id | TEXT FOREIGN KEY | Links to students.id |
| class_id | TEXT FOREIGN KEY | Links to classes.id |
| subject | TEXT NOT NULL | Mathematics, Science, etc. |
| exam_type | TEXT NOT NULL | Unit Test, Half Yearly, Annual |
| marks_obtained | REAL NOT NULL | Marks scored |
| total_marks | REAL NOT NULL | Maximum marks |
| grade | TEXT | Calculated grade (A+, A, B+...) |
| exam_date | TEXT NOT NULL | Date of exam |

### fees
| Column | Type | Description |
|---|---|---|
| id | TEXT PRIMARY KEY | Unique fee ID |
| student_id | TEXT FOREIGN KEY | Links to students.id |
| student_name | TEXT NOT NULL | Denormalized for quick display |
| fee_type | TEXT NOT NULL | tuition, transport, lab, etc. |
| amount | REAL NOT NULL | Total fee amount |
| paid_amount | REAL NOT NULL | How much has been paid |
| due_amount | REAL NOT NULL | Remaining balance |
| status | TEXT NOT NULL | paid, pending, overdue |
| paid_date | TEXT | When payment was made |

### Other Tables
- **classes**: class_name + section + stream
- **timetable**: class → day → period → subject → teacher mapping
- **notices**: school-wide announcements with expiry
- **sync_queue**: local queue of unsynced changes
- **sync_conflicts**: records where local and server data conflicted

## 7.2 SQLite Migration System

When the app upgrades from version 1 to version 2:
```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final newCols = ['parent_occupation TEXT', 'mother_name TEXT', ...];
      for (final col in newCols) {
        try {
          await db.execute('ALTER TABLE students ADD COLUMN $col');
        } catch (_) {} // Column may already exist — safe to ignore
      }
    }
  }
```
**Why try/catch?** If someone reinstalls the app, the CREATE TABLE already has these columns. ALTER TABLE would fail with "duplicate column name". The catch block silently ignores this — making the migration **idempotent** (safe to run multiple times).

---

# 8. Authentication System

## 8.1 Complete Auth Flow

```
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│ Login Screen │          │   Backend    │          │  PostgreSQL  │
│ (Flutter)    │          │  (Express)   │          │  (Neon.tech) │
└──────┬───────┘          └──────┬───────┘          └──────┬───────┘
       │                        │                         │
       │ POST /api/auth/login   │                         │
       │ {email, password}      │                         │
       │───────────────────────>│                         │
       │                        │ SELECT * FROM users     │
       │                        │ WHERE email = ?         │
       │                        │────────────────────────>│
       │                        │                         │
       │                        │ {id, password_hash,     │
       │                        │  role}                  │
       │                        │<────────────────────────│
       │                        │                         │
       │                        │ bcrypt.compare()        │
       │                        │ jwt.sign()              │
       │                        │                         │
       │ {token, role, userId}  │                         │
       │<───────────────────────│                         │
       │                        │                         │
       │ Save to SharedPrefs    │                         │
       │ Set userRoleProvider   │                         │
       │ Navigate to Dashboard  │                         │
       │                        │                         │
```

## 8.2 Password Security

Passwords are NEVER stored as plain text. The process:

1. **Registration**: `bcrypt.hash("admin", 10)` → `$2b$10$abc123...`
   - `10` is the "salt rounds" — how many times the hash is computed (more = slower = harder to crack)
2. **Login**: `bcrypt.compare("admin", "$2b$10$abc123...")` → `true`
3. Even if the database is leaked, attackers cannot reverse the hash to get passwords

## 8.3 JWT Token Structure

A JWT token has 3 parts separated by dots: `header.payload.signature`

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOjEsInJvbGUiOiJhZG1pbiJ9.xyz123
```

Decoded:
- **Header**: `{"alg": "HS256"}` — algorithm used for signing
- **Payload**: `{"userId": 1, "role": "admin", "exp": 1775238489}` — user data + expiry
- **Signature**: HMAC-SHA256 hash of header+payload using JWT_SECRET

## 8.4 Session Persistence

```dart
class AuthRepository {
  Future<void> saveSession(String token, String role, {String userId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_role', role);
    await prefs.setString('user_id', userId);
  }
}
```
**SharedPreferences** stores small key-value pairs in:
- Android: `/data/data/com.example.kvm_erp/shared_prefs/`
- iOS: `NSUserDefaults`
- Windows: Registry or AppData folder

This survives app restarts but NOT app uninstall.

---

# 9. Sync Engine — Offline-First Architecture

## 9.1 Why Sync is the Hardest Part

In a normal app: User → API → Database. Simple.

In an offline-first app:
- User A adds a student on Phone A (no internet)
- User B adds a student on Phone B (no internet)
- Both phones come online and try to sync
- **What if both modified the same student?** This is a **conflict**.

## 9.2 The Sync Queue

Every time a repository writes data, it also queues a sync job:

```dart
void _queueSync(String tableName, String recordId, String action, Map data) async {
    await _dbService.insert('sync_queue', {
      'table_name': tableName,    // "students"
      'record_id': recordId,      // student's UUID
      'action': action,           // "INSERT" or "UPDATE"
      'data': data.toString(),    // The actual data as JSON
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,                // 0 = pending
      'attempt_count': 0,         // How many times we tried
    });
}
```

## 9.3 Push Flow (Phone → Cloud)

```dart
Future<void> pushSyncQueue(String token) async {
    // 1. Read all pending jobs from sync_queue
    final queue = await db.query('sync_queue',
      where: 'synced = 0 AND attempt_count < 3');  // Max 3 retries

    // 2. Group by table: { "students": [...], "attendance": [...] }
    Map<String, List> payload = {};

    // 3. Send to server
    http.post('/api/sync/push', body: jsonEncode(payload));

    // 4. If success: mark all jobs as synced
    // 5. If failure: increment attempt_count, mark as failed after 3 tries
}
```

## 9.4 Pull Flow (Cloud → Phone)

```dart
Future<void> fetchServerChanges(String token) async {
    // 1. Get last sync timestamp from SharedPreferences
    final lastSync = prefs.getInt('last_sync_at');

    // 2. Request only changes since last sync
    http.get('/api/sync/pull?lastSync=$lastSync');

    // 3. For each table in the response:
    //    a. Check if record exists locally
    //    b. If not → INSERT
    //    c. If exists → compare updated_at → UPDATE only if server is newer
    //    d. Coerce data types (bool→int, id→string)
}
```

## 9.5 Conflict Resolution Strategy

The system uses **Last Write Wins (LWW)** with `updated_at` comparison:

```sql
-- Server side (PostgreSQL)
ON CONFLICT (id) DO UPDATE SET ...
WHERE "students".updated_at < EXCLUDED.updated_at
-- Only update if incoming data is NEWER
```

```dart
// Client side (SQLite)
if (serverUpdatedAt.isAfter(localUpdatedAt)) {
    await txn.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
}
```

---

# 10. Feature Modules Explained

## 10.1 Authentication Module (`features/auth/`)

| File | Purpose |
|---|---|
| `login_screen.dart` | Username + Password form with validation |
| `auth_provider.dart` | Login/Logout logic, AuthState, UserRole enum |
| `auth_repository.dart` | SharedPreferences read/write for session |

## 10.2 Dashboard Module (`features/dashboard/`)

Each role has its own dashboard:

| Dashboard | What It Shows |
|---|---|
| **AdminDashboard** | Total students, teachers, classes stats + 6 quick action buttons |
| **TeacherDashboard** | 4 action cards: Attendance, Marks, Timetable, Students |
| **AccountantDashboard** | 2-tab view: Student list + Due Fees summary |
| **ParentDashboard** | Sibling toggle + 4 tiles: Attendance, Fees, Marks, Alerts |
| **StudentDashboard** | Personal attendance, marks, and fee overview |

## 10.3 Students Module (`features/students/`)

| Screen | What It Does |
|---|---|
| **StudentsScreen** | List all students with search, filter (class/gender/category), sort |
| **AddStudentScreen** | 4-step Stepper form: Personal → Background → Family → Education |
| **StudentDetailScreen** | 4-tab view: Profile, Attendance summary, Results, Fee history |

The 4-step Add Student form collects:
1. **Step 1 — Personal**: Name, Roll, Class (LKG-12), Phone, Email, Gender, DOB, Blood Group, Aadhar
2. **Step 2 — Background**: Category (General/OBC/SC/ST/EWS), Caste, Religion, Nationality
3. **Step 3 — Family & Address**: Father name/phone/occupation, Mother name/phone, Full address
4. **Step 4 — Previous Education**: Previous school name, Previous class/grade

## 10.4 Attendance Module (`features/attendance/`)

- Class filter dropdown
- Date picker
- List of students with **P** (Present) and **A** (Absent) buttons
- Stats bar showing present/absent count
- Saves to local SQLite with `UNIQUE(student_id, date, period_number)` constraint

## 10.5 Marks Module (`features/marks/`)

- 2-tab interface: **Enter Marks** + **Class Ranks**
- Subject and exam type selection
- Batch marks entry for all students in a class
- Server-side rank calculation with 🏆 trophies for top 3

## 10.6 Fees Module (`features/fees/`)

| Screen | Purpose |
|---|---|
| **FeesScreen (Admin)** | Class-wise student list, Paid/Due filter, grand total banner |
| **StudentFeeScreen** | Individual student's fee details (for Students) |
| **ParentFeeScreen** | Fee view for parents (with sibling support) |

## 10.7 Timetable Module (`features/timetable/`)

| Screen | Purpose |
|---|---|
| **TimetableScreen** | Teacher view: day-tabbed schedule |
| **TimetableManagerScreen** | Admin: week-grid DataTable + add slots with clash detection (409) |

---

# 11. State Management with Riverpod

## 11.1 What is State Management?

"State" = the current data your app is showing. For example:
- Which user is logged in? (auth state)
- Which students are loaded? (student list state)
- Is the sync running? (sync state)

Without state management, passing data between screens becomes a mess of constructor parameters.

## 11.2 Why Riverpod?

Flutter has many state management options: setState, Provider, Bloc, GetX, Riverpod. KVM ERP uses **Riverpod** because:
- **Compile-safe**: Errors are caught at compile time, not runtime
- **Testable**: Easy to mock for unit tests
- **No BuildContext needed**: Can access state from anywhere
- **Auto-dispose**: Providers clean up when no longer needed

## 11.3 Types of Providers Used

```dart
// 1. Provider — Creates a single instance (like a service)
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(SQLiteService());
});

// 2. StateProvider — Simple mutable value
final userRoleProvider = StateProvider<UserRole>((ref) => UserRole.admin);

// 3. FutureProvider — Async data that auto-handles loading/error states
final studentsListProvider = FutureProvider.autoDispose<List<StudentModel>>((ref) async {
  return ref.watch(studentRepositoryProvider).getAllStudents(limit: 500, offset: 0);
});

// 4. StateNotifierProvider — Complex state with methods
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
```

## 11.4 How Data Flows

```
UI (Widget)
    │
    │ ref.watch(studentsListProvider)  ← Reactively listens
    │
    ▼
Provider (studentsListProvider)
    │
    │ ref.watch(studentRepositoryProvider)  ← Depends on repo
    │
    ▼
Repository (StudentRepository)
    │
    │ _dbService.query('students')  ← Queries SQLite
    │
    ▼
SQLiteService → Returns List<StudentModel>
```

When data changes:
```
User deletes a student
    │
    │ ref.read(studentRepositoryProvider).deleteStudentSoft(id)
    │
    ▼
Repository updates SQLite + queues sync
    │
    │ ref.invalidate(studentsListProvider)  ← Forces re-fetch
    │
    ▼
Provider re-runs → returns new list without deleted student
    │
    ▼
UI automatically rebuilds with new data
```

---

# 12. Deployment & DevOps

## 12.1 The Deployment Pipeline

```
Developer's PC
    │
    │ git push origin main
    │
    ▼
GitHub (github.com/Sanskar-2004/kvm-erp)
    │
    │ Webhook triggers
    │
    ▼
Render.com
    │
    │ Pulls code → npm install → npm start
    │
    ▼
Live at https://kvm-erp.onrender.com
```

## 12.2 Building the APK

```bash
flutter build apk --release
```

This produces: `build/app/outputs/flutter-apk/app-release.apk` (57.4 MB)

**Critical requirement**: The `INTERNET` permission must be in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
Without this, the release APK cannot make ANY network requests.

## 12.3 Environment Variables

The `.env` file contains secrets:
```
DATABASE_URL=postgresql://user:pass@host/dbname?sslmode=require
JWT_SECRET=your-secret-key-here
PORT=3000
```
**NEVER commit .env to Git.** The `.gitignore` file ensures this.

---

# 13. Security Practices

| Practice | Implementation |
|---|---|
| Password hashing | bcrypt with 10 salt rounds |
| Token-based auth | JWT with 7-day expiry |
| SQL injection prevention | Parameterized queries ($1, $2...) |
| Table whitelist | Only 15 specific tables allowed in sync |
| SSL/TLS | Encrypted database connection |
| Session cleanup | Stale token detection on app boot |
| Soft deletes | Records are marked `is_deleted=1`, not actually deleted |
| CORS | Server allows cross-origin requests from Flutter app |

---

# 14. Glossary of Terms

| Term | Meaning |
|---|---|
| **API** | Application Programming Interface — how the app talks to the server |
| **APK** | Android Package — the installable app file for Android |
| **Async/Await** | Dart's way of handling operations that take time (network, database) |
| **Backend** | Server-side code that processes requests and manages the database |
| **bcrypt** | A password hashing algorithm that's intentionally slow to prevent brute-force attacks |
| **CORS** | Cross-Origin Resource Sharing — security mechanism for web requests |
| **CRUD** | Create, Read, Update, Delete — the four basic database operations |
| **Dart** | The programming language used by Flutter |
| **ERP** | Enterprise Resource Planning — system to manage an organization's resources |
| **Express.js** | Web framework for Node.js that simplifies creating APIs |
| **FFI** | Foreign Function Interface — allows Dart to call C code directly |
| **Flutter** | Google's UI toolkit for building cross-platform apps |
| **Foreign Key** | A column that references the primary key of another table |
| **Frontend** | Client-side code (the app the user sees and interacts with) |
| **Git** | Version control system that tracks code changes |
| **HTTP** | HyperText Transfer Protocol — how the internet communicates |
| **Idempotent** | An operation that gives same result no matter how many times you run it |
| **JWT** | JSON Web Token — a secure way to represent user identity |
| **Material Design** | Google's design system for consistent, beautiful UIs |
| **Middleware** | Code that runs between receiving a request and processing it |
| **Node.js** | JavaScript runtime for server-side programming |
| **PoS** | Proof of Sync — the `is_synced` flag on each record |
| **PostgreSQL** | Powerful open-source relational database |
| **Primary Key** | A unique identifier for each row in a table |
| **Provider** | A Riverpod concept — an object that supplies data to widgets |
| **REST API** | Representational State Transfer — a style of web API design |
| **Riverpod** | State management library for Flutter |
| **Route** | A URL path that maps to a specific server function |
| **SHA-256** | A cryptographic hash function used in JWT signatures |
| **SharedPreferences** | Key-value storage that persists across app restarts |
| **Soft Delete** | Marking a record as deleted (is_deleted=1) instead of actually removing it |
| **SQL** | Structured Query Language — language for databases |
| **SQLite** | Lightweight embedded database that runs on the phone |
| **SSL/TLS** | Encryption protocol for secure internet communication |
| **State** | The current data/condition of the application at any point |
| **Stepper** | A Flutter widget that guides users through a multi-step form |
| **UPSERT** | INSERT + UPDATE — insert if new, update if exists |
| **UUID** | Universally Unique Identifier — a 128-bit unique ID |
| **Widget** | Flutter's building block — everything on screen is a widget |

---

> **Document Version**: 1.0
> **Last Updated**: April 2026
> **Project**: KVM ERP School Management System
> **Repository**: github.com/Sanskar-2004/kvm-erp
> **Live Backend**: kvm-erp.onrender.com
