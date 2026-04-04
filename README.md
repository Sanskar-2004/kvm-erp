# KVM ERP — School Management System

A **school management ERP** built with Flutter (offline-first) + Node.js backend. 5 user roles, admission workflows, fee management with discounts, timetable with clash detection, marks with server-side ranking, parent sibling system, and interactive dashboards.

## Tech Stack

| Layer | Tech |
|---|---|
| Frontend | Flutter + Dart + Riverpod |
| Backend | Node.js + Express.js |
| Cloud DB | PostgreSQL (Neon.tech) — 12 tables |
| Local DB | SQLite (sqflite) |
| Auth | JWT (7d) + bcrypt + userId persistence |
| Sync | Timestamp UPSERT + conflict resolution |
| Deploy | GitHub → Render.com (auto-deploy) |

## Getting Started

### Prerequisites
- Flutter SDK
- Node.js 18+
- PostgreSQL database

### Backend Setup
```bash
cd backend
npm install
cp .env.example .env   # Configure your DATABASE_URL and JWT_SECRET
node run-migration.js   # Create base tables
node seed-users.js      # Seed test accounts
npm start
```

### Flutter Setup
```bash
flutter pub get
flutter run
```

## Login Credentials

| Username | Password | Role |
|---|---|---|
| `admin` | `admin` | Admin |
| `teacher` | `teacher` | Teacher |
| `accountant` | `accountant` | Accountant |
| `parent` | `parent` | Parent |
| `student` | `student` | Student |

> **Note:** Login uses username-based authentication. Type just the username (e.g., `admin`) — no email required.

## Role System (5 Roles)

| Role | Key Capabilities |
|---|---|
| **Admin** | Full access, admissions, redesigned timetable manager, student filters (Nursery-12, Male/Female, caste categories) |
| **Teacher** | Class-filtered attendance (assigned classes only), per-student marks entry (exam/subject selectors), class ranks, teacher-specific timetable from API |
| **Accountant** | Full class list (Nursery-12), fees overview (6 stats + progress + last 10 txns), student fee detail, parent alerts |
| **Parent** | Sibling toggle, child profile card (tap for full details), attendance/fee/marks/alerts tiles |
| **Student** | Own dashboard with profile card (tap for full details), attendance, fees, marks, alerts |

> **Class System:** All class dropdowns across the app support: Nursery → KG1 → KG2 → 1 through 12.

## API (7 Route Groups, 21+ Endpoints)

| Route | Auth | Key Features |
|---|---|---|
| `/api/auth` | Public | register, login (returns token + role + userId) |
| `/api/sync` | JWT | push (13 tables), pull |
| `/api/students` | JWT | pending, status update |
| `/api/fees` | JWT | CRUD, generate, alerts (used by accountant for parent notifications) |
| `/api/timetable` | JWT | create (409 clash), class, teacher |
| `/api/admin` | JWT (admin) | finance-summary, ranks, due-fees (reused by accountant) |
| `/api/parent` | JWT | children, link, summary (receives fee alerts) |

## Deployment

| Component | Location |
|---|---|
| GitHub | `github.com/Sanskar-2004/kvm-erp` |
| Backend | `https://kvm-erp.onrender.com` |
| Database | Neon.tech PostgreSQL |
