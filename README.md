# KVM ERP — School Management System

A full-featured **school management ERP** built with **Flutter (offline-first)** and a **Node.js** backend. Supports 5 user roles, admission workflows, fee management with discounts, timetable with clash detection, marks with server-side ranking, parent–sibling system, AI assistant, staff management, academics center, and role-based interactive dashboards.

> **Live Demo:** Deployed on Vercel (Flutter Web) + Render.com (Node.js API)

---

## ✨ Features at a Glance

| Module | Highlights |
|---|---|
| 🔐 **Authentication** | JWT-based login (7-day tokens), bcrypt hashing, role detection, session persistence |
| 📊 **Dashboards** | 5 role-specific dashboards (Admin, Teacher, Accountant, Parent, Student) |
| 👨‍🎓 **Students** | Full CRUD, class filters (Nursery–12), gender/caste filters, Excel bulk import |
| 📋 **Attendance** | Class-filtered marking, bulk submit, date-wise tracking |
| 💰 **Fees** | Fee generation, discount support, payment tracking, parent alerts, student/parent fee views |
| 📝 **Marks** | Per-student entry with exam/subject selectors, class ranks, tabbed marks sheet |
| 📅 **Timetable** | Day-wise schedule, clash detection (409), teacher-specific timetable |
| 📢 **Notices** | Create & broadcast alerts, role-based visibility |
| 🎓 **Academics** | Academic center with class/subject management, analytics |
| 📥 **Admissions** | Admission approval workflow with status tracking |
| 👨‍💼 **Staff** | Staff directory, add/edit staff, role assignment |
| 🤖 **AI Assistant** | Built-in AI chat for quick queries |
| 💾 **Backup** | System backup & restore functionality |
| 🔄 **Sync** | Offline-first with timestamp UPSERT, conflict resolution, dead queue audit |

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter + Dart + Riverpod (state management) |
| **Backend** | Node.js + Express.js |
| **Cloud DB** | PostgreSQL (Neon.tech) — 12+ tables |
| **Local DB** | SQLite (sqflite + sqflite_common_ffi_web) |
| **Auth** | JWT (7-day expiry) + bcrypt + userId persistence |
| **Sync Engine** | Timestamp-based UPSERT + conflict resolution + dead queue |
| **Styling** | Google Fonts (Inter) + Material 3 |
| **Excel Import** | `excel` + `file_picker` packages |
| **Web Deploy** | Vercel (Flutter Web via `build.sh`) |
| **API Deploy** | Render.com (auto-deploy from GitHub) |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (≥3.0.0)
- Node.js 18+
- PostgreSQL database (or Neon.tech free tier)

### Backend Setup

```bash
cd backend
npm install
cp .env.example .env   # Configure DATABASE_URL and JWT_SECRET
node run-migration.js   # Create base tables
node seed-users.js      # Seed test accounts
npm start
```

### Flutter Setup

```bash
flutter pub get
flutter run                  # Mobile/Desktop
flutter run -d chrome        # Web
```

### Build for Web (Vercel)

```bash
flutter build web --release
# Output: build/web/
```

---

## 🔑 Login Credentials

| Username | Password | Role |
|---|---|---|
| `admin` | `admin` | Admin |
| `teacher` | `teacher` | Teacher |
| `accountant` | `accountant` | Accountant |
| `parent` | `parent` | Parent |
| `student` | `student` | Student |

> **Note:** Login is username-based — no email required. Just type the username (e.g., `admin`).

---

## 👥 Role System (5 Roles)

### Admin
- Full access to all modules
- Student management with class filters (Nursery → KG1 → KG2 → 1–12), gender, and caste category filters
- Admission approval workflow
- Timetable manager with clash detection
- Staff directory management
- Financial overview dashboard
- System backup & restore
- Sync audit & dead queue monitoring
- Excel bulk import for students

### Teacher
- Class-filtered attendance (assigned classes only)
- Per-student marks entry with exam/subject selectors
- Class rank generation
- Teacher-specific timetable from API
- Student list (assigned classes)

### Accountant
- Full class list (Nursery–12)
- Fees overview (6 stats + progress bar + last 10 transactions)
- Student fee detail with discount support
- Parent fee alert notifications

### Parent
- Sibling toggle (switch between children)
- Child profile card (tap for full details)
- Attendance, fees, marks, and alerts tiles
- Fee payment history

### Student
- Personal dashboard with profile card
- Own attendance records
- Fee status and payment history
- Marks and academic performance
- Notice board

> **Class System:** All class dropdowns support: `Nursery → KG1 → KG2 → 1 through 12`

---

## 🌐 API (9 Route Groups)

| Route | Auth | Key Features |
|---|---|---|
| `/api/auth` | Public | Register, login (returns token + role + userId) |
| `/api/sync` | JWT | Push (13 tables), pull with timestamps |
| `/api/students` | JWT | Pending admissions, status update, CRUD |
| `/api/fees` | JWT | CRUD, generate, alerts (accountant → parent notifications) |
| `/api/timetable` | JWT | Create (409 clash detection), class schedule, teacher schedule |
| `/api/admin` | JWT (admin) | Finance summary, ranks, due fees (reused by accountant) |
| `/api/parent` | JWT | Children list, link, summary (receives fee alerts) |
| `/api/staff` | JWT | Staff CRUD, directory |
| `/api/assignments` | JWT | Assignment management |

---

## 📁 Project Structure

```
KVM/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── app_router.dart            # Route definitions
│   ├── core/
│   │   ├── constants/             # App-wide constants
│   │   ├── utils/                 # Utilities (academic year, etc.)
│   │   └── widgets/               # Shared widgets (MainLayout, SyncBadge)
│   ├── features/
│   │   ├── academics/             # Academic center
│   │   ├── admission/             # Admission approvals
│   │   ├── ai/                    # AI chat assistant
│   │   ├── attendance/            # Attendance marking
│   │   ├── auth/                  # Login, auth providers
│   │   ├── backup/                # Backup & restore
│   │   ├── dashboard/             # 5 role-specific dashboards
│   │   ├── fees/                  # Fee management (admin, student, parent views)
│   │   ├── marks/                 # Marks entry & class ranks
│   │   ├── notices/               # Notice board
│   │   ├── staff/                 # Staff directory
│   │   ├── students/              # Student CRUD + Excel import
│   │   ├── sync/                  # Conflict logs & dead queue
│   │   └── timetable/             # Day-wise timetable
│   ├── models/                    # Data models
│   └── services/
│       ├── db/                    # SQLite service
│       ├── sync/                  # Sync engine
│       ├── backup/                # Backup service
│       └── excel/                 # Excel import service
├── backend/
│   └── src/
│       ├── server.js              # Express server entry
│       ├── config/                # DB config
│       ├── controllers/           # Route handlers
│       ├── db/                    # Migrations & seeds
│       ├── middleware/            # JWT auth middleware
│       └── routes/                # 9 route files
├── web/                           # Flutter web assets
├── build.sh                       # Vercel build script
├── vercel.json                    # Vercel config (SPA rewrites)
└── pubspec.yaml                   # Flutter dependencies
```

---

## 🏗 Architecture

### Offline-First Sync

The app works fully offline using **SQLite** and syncs with the **PostgreSQL** cloud database when online:

1. All writes go to local SQLite first
2. Changes are queued in a `sync_queue` table
3. Background sync pushes changes to the server via timestamp-based UPSERT
4. Conflicts are resolved automatically with last-write-wins
5. Failed sync items are moved to a dead queue for admin audit

### Navigation

- **MainLayout** uses `BottomNavigationBar` with index-based screen switching (no route push)
- Sub-screens (e.g., Student Detail, Add Student) are pushed via `Navigator.push`
- Back buttons are **conditional** — only shown when `Navigator.canPop(context)` is true
- Auto-sync triggers every 30 minutes + on every local write

---

## 🌍 Deployment

| Component | Platform | URL |
|---|---|---|
| **Frontend** | Vercel | Flutter Web (auto-deploy from `main`) |
| **Backend** | Render.com | `https://kvm-erp.onrender.com` |
| **Database** | Neon.tech | PostgreSQL (serverless) |
| **Source** | GitHub | [github.com/Sanskar-2004/kvm-erp](https://github.com/Sanskar-2004/kvm-erp) |

### Vercel Config

```json
{
  "version": 2,
  "cleanUrls": true,
  "outputDirectory": "build/web",
  "buildCommand": "bash build.sh",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `sqflite` / `sqflite_common_ffi_web` | Local SQLite database |
| `http` | REST API calls |
| `google_fonts` | Inter font family |
| `shared_preferences` | Session persistence |
| `excel` | Excel file parsing for bulk import |
| `file_picker` | File selection UI |
| `uuid` | Unique ID generation |
| `intl` | Date/number formatting |
| `path_provider` | File system paths |

---

## 📄 License

This project is for educational purposes.

---

Built with ❤️ by [Sanskar](https://github.com/Sanskar-2004)
